import re
import time

import httpx
import yt_dlp
from fastapi import FastAPI, HTTPException, Request
from fastapi.concurrency import run_in_threadpool
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from ytmusicapi import YTMusic

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

_cache = {}  # video_id -> (expire_ts, url, headers)

try:
    _ytm = YTMusic()
except Exception:
    _ytm = None


@app.get("/")
def root():
    return {"status": "ok", "app": "vycustic"}


# ---------------- Pencarian ----------------
def _hd(url: str, vid: str) -> str:
    if not url:
        return f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"
    if "googleusercontent" in url or "ggpht" in url:
        return re.sub(r"=w\d+-h\d+.*$", "=w544-h544-l90-rj", url)
    return url


def _search_music(q: str, kind: str):
    res = _ytm.search(q, filter=kind, limit=25)
    out = []
    for r in res:
        vid = r.get("videoId")
        if not vid:
            continue
        artists = ", ".join(a.get("name", "") for a in (r.get("artists") or []) if a.get("name"))
        thumbs = r.get("thumbnails") or []
        out.append({
            "id": vid,
            "title": r.get("title"),
            "artist": artists,
            "duration": r.get("duration_seconds"),
            "thumbnail": _hd(thumbs[-1]["url"] if thumbs else "", vid),
        })
    return out


def _search_fallback(q: str):
    opts = {"quiet": True, "extract_flat": True, "skip_download": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(f"ytsearch20:{q}", download=False)
    out = []
    for e in info.get("entries", []):
        vid = e.get("id")
        if not vid:
            continue
        out.append({
            "id": vid,
            "title": e.get("title"),
            "artist": e.get("uploader") or e.get("channel") or "",
            "duration": e.get("duration"),
            "thumbnail": f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg",
        })
    return out


@app.get("/search")
def search(q: str, type: str = "songs"):
    # type: "songs" (katalog YouTube Music) atau "videos"
    kind = "videos" if type == "videos" else "songs"
    results = []
    if _ytm is not None:
        try:
            results = _search_music(q, kind)
        except Exception:
            results = []
    if not results:
        results = _search_fallback(q)
    return {"results": results}


@app.get("/suggest")
def suggest(q: str):
    if _ytm is None or not q.strip():
        return {"suggestions": []}
    try:
        return {"suggestions": [str(x) for x in _ytm.get_search_suggestions(q.strip())][:8]}
    except Exception:
        return {"suggestions": []}


# ---------------- Lirik ----------------
def _clean(t: str) -> str:
    return re.sub(r"\s*[\(\[][^\)\]]*[\)\]]", "", t or "").strip()


_LRC_RE = re.compile(r"\[(\d+):(\d+(?:\.\d+)?)\]")


def _parse_lrc(lrc: str):
    lines = []
    for raw in lrc.splitlines():
        stamps = _LRC_RE.findall(raw)
        if not stamps:
            continue
        text = _LRC_RE.sub("", raw).strip()
        for mm, ss in stamps:
            lines.append({"t": int((int(mm) * 60 + float(ss)) * 1000), "text": text})
    lines.sort(key=lambda x: x["t"])
    return lines


def _lrclib(title: str, artist: str, duration: int):
    q = f"{_clean(title)} {artist.split(',')[0].strip()}".strip()
    if not q:
        return None
    try:
        r = httpx.get(
            "https://lrclib.net/api/search",
            params={"q": q},
            timeout=10,
            headers={"User-Agent": "Vycustic/1.0"},
        )
        data = r.json() if r.status_code == 200 else []
    except Exception:
        return None
    plain = None
    for d in data:
        dd = d.get("duration")
        if duration and dd and abs(dd - duration) > 6:
            continue
        if d.get("syncedLyrics"):
            lines = _parse_lrc(d["syncedLyrics"])
            if lines:
                return {"synced": True, "lines": lines, "source": "LRCLIB"}
        if plain is None and d.get("plainLyrics"):
            plain = d["plainLyrics"]
    if plain:
        return {
            "synced": False,
            "lines": [{"t": None, "text": t} for t in plain.splitlines()],
            "source": "LRCLIB",
        }
    return None


def _line_parts(x):
    if isinstance(x, dict):
        return x.get("text", ""), x.get("start_time")
    return getattr(x, "text", ""), getattr(x, "start_time", None)


def _yt_lyrics(vid: str):
    if _ytm is None:
        return None
    try:
        wp = _ytm.get_watch_playlist(videoId=vid, limit=1)
        bid = wp.get("lyrics")
        if not bid:
            return None
    except Exception:
        return None
    for ts in (True, False):
        try:
            l = _ytm.get_lyrics(bid, timestamps=ts)
        except Exception:
            continue
        if not l:
            continue
        content = l.get("lyrics") if isinstance(l, dict) else getattr(l, "lyrics", None)
        source = (l.get("source", "") if isinstance(l, dict) else "") or "YouTube Music"
        if isinstance(content, list):
            lines = []
            for x in content:
                text, st = _line_parts(x)
                lines.append({"t": int(st) if st is not None else None, "text": text})
            if lines:
                return {"synced": any(i["t"] is not None for i in lines), "lines": lines, "source": source}
        elif isinstance(content, str) and content.strip():
            return {
                "synced": False,
                "lines": [{"t": None, "text": t} for t in content.splitlines()],
                "source": source,
            }
    return None


@app.get("/lyrics")
def lyrics(id: str, title: str = "", artist: str = "", duration: int = 0):
    lr = _lrclib(title, artist, duration)
    if lr and lr["synced"]:
        return lr
    yt = _yt_lyrics(id)
    if yt:
        return yt
    if lr:
        return lr
    return {"synced": False, "lines": [], "source": ""}


# ---------------- Stream audio ----------------
def _get_audio(vid: str):
    hit = _cache.get(vid)
    if hit and hit[0] > time.time():
        return hit[1], hit[2]
    opts = {"quiet": True, "format": "bestaudio[ext=m4a]/bestaudio/best", "noplaylist": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(f"https://www.youtube.com/watch?v={vid}", download=False)
    url, headers = info["url"], info.get("http_headers", {})
    _cache[vid] = (time.time() + 3600, url, headers)
    return url, headers


@app.get("/stream/{vid}")
async def stream(vid: str, request: Request):
    try:
        url, headers = await run_in_threadpool(_get_audio, vid)
    except Exception:
        raise HTTPException(status_code=502, detail="Gagal ambil audio")
    h = dict(headers)
    if request.headers.get("range"):
        h["Range"] = request.headers["range"]
    client = httpx.AsyncClient(follow_redirects=True, timeout=None)
    r = await client.send(client.build_request("GET", url, headers=h), stream=True)
    out = {
        k: r.headers[k]
        for k in ("content-type", "content-length", "content-range", "accept-ranges")
        if k in r.headers
    }

    async def gen():
        try:
            async for chunk in r.aiter_raw():
                yield chunk
        finally:
            await r.aclose()
            await client.aclose()

    return StreamingResponse(gen(), status_code=r.status_code, headers=out)
