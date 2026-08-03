// ────────────────────────────────────────────────────────────
//  http.ox  –  HTTP client library (reqwest-inspired)
//  Usage:
//    import http
//    let resp = http.get("https://api.example.com/users")
//    print(resp.status())
//    print(resp.text())
//
//  With custom headers:
//    var client = http.Client()
//    client = client.header("Authorization", "Bearer token123")
//    let resp = client.get("https://api.example.com/data")
// ────────────────────────────────────────────────────────────

// ── Response class ──────────────────────────────────────────
pub class HttpResponse {
    status_code: int
    status_text: str
    body: str
    headers: Map<str, str>

    pub fn ok(self) -> bool {
        return self.status_code >= 200 and self.status_code < 300
    }

    pub fn text(self) -> str {
        return self.body
    }

    pub fn status(self) -> int {
        return self.status_code
    }

    pub fn header(self, name: str) -> Option<str> {
        if map_contains(self.headers, name) {
            return Some(map_get(self.headers, name))
        }
        return None
    }

    pub fn json(self) -> Result<JsonValue, str> {
        return Ok(json_parse(self.body))
    }
}

// ── Client class (immutable builder) ───────────────────────
pub class Client {
    headers: Map<str, str>
    timeout: int

    pub fn create() -> Client {
        return Client { headers: Map<str, str>(), timeout: 30 }
    }

    pub fn header(self, name: str, value: str) -> Client {
        var h: Map<str, str> = self.headers
        map_set(h, name, value)
        return Client { headers: h, timeout: self.timeout }
    }

    pub fn with_timeout(self, secs: int) -> Client {
        return Client { headers: self.headers, timeout: secs }
    }

    pub fn get(self, url: str) -> Result<HttpResponse, str> {
        let hdrs = _ox_http_headers_to_json(self.headers)
        let raw = _ox_http_request("GET", url, hdrs, "", self.timeout)
        return _parse_response(raw)
    }

    pub fn post(self, url: str, body: str) -> Result<HttpResponse, str> {
        let hdrs = _ox_http_headers_to_json(self.headers)
        let raw = _ox_http_request("POST", url, hdrs, body, self.timeout)
        return _parse_response(raw)
    }

    pub fn put(self, url: str, body: str) -> Result<HttpResponse, str> {
        let hdrs = _ox_http_headers_to_json(self.headers)
        let raw = _ox_http_request("PUT", url, hdrs, body, self.timeout)
        return _parse_response(raw)
    }

    pub fn http_delete(self, url: str) -> Result<HttpResponse, str> {
        let hdrs = _ox_http_headers_to_json(self.headers)
        let raw = _ox_http_request("DELETE", url, hdrs, "", self.timeout)
        return _parse_response(raw)
    }

    pub fn patch(self, url: str, body: str) -> Result<HttpResponse, str> {
        let hdrs = _ox_http_headers_to_json(self.headers)
        let raw = _ox_http_request("PATCH", url, hdrs, body, self.timeout)
        return _parse_response(raw)
    }
}

// ── Internal helpers ───────────────────────────────────────
fn _parse_response(raw: str) -> Result<HttpResponse, str> {
    let obj = json_parse(raw)
    let ok_val = json_get(obj, "ok")
    if ok_val.is_some() and json_as_bool(ok_val.value) == false {
        let err_val = json_get(obj, "error")
        if err_val.is_some() {
            return Err(json_as_str(err_val.value))
        }
        return Err("unknown error")
    }
    var status: int = 0
    var status_text: str = ""
    var body: str = ""
    var hdrs_json: str = "{}"
    let sv = json_get(obj, "status")
    if sv.is_some() { status = json_as_int(sv.value) }
    let stv = json_get(obj, "status_text")
    if stv.is_some() { status_text = json_as_str(stv.value) }
    let bv = json_get(obj, "body")
    if bv.is_some() { body = json_as_str(bv.value) }
    let hv = json_get(obj, "headers")
    if hv.is_some() { hdrs_json = json_as_str(hv.value) }
    let hdrs_parsed = json_parse(hdrs_json)
    let keys = json_keys(hdrs_parsed)
    var headers: Map<str, str> = Map<str, str>()
    var i = 0
    while i < len(keys) {
        let k = keys[i]
        let v = json_get(hdrs_parsed, k)
        if v.is_some() {
            map_set(headers, k, json_as_str(v.value))
        }
        i = i + 1
    }
    return Ok(HttpResponse {
        status_code: status,
        status_text: status_text,
        body: body,
        headers: headers
    })
}

// ── Convenience functions ──────────────────────────────────
pub fn get(url: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("GET", url, "{}", "", 30)
    return _parse_response(raw)
}

pub fn post(url: str, body: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("POST", url, "{}", body, 30)
    return _parse_response(raw)
}

pub fn put(url: str, body: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("PUT", url, "{}", body, 30)
    return _parse_response(raw)
}

pub fn http_delete(url: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("DELETE", url, "{}", "", 30)
    return _parse_response(raw)
}

pub fn patch(url: str, body: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("PATCH", url, "{}", body, 30)
    return _parse_response(raw)
}

pub fn head(url: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("HEAD", url, "{}", "", 30)
    return _parse_response(raw)
}

pub fn options(url: str) -> Result<HttpResponse, str> {
    let raw = _ox_http_request("OPTIONS", url, "{}", "", 30)
    return _parse_response(raw)
}
