/// Primary catalog browsing UI (toys list + filters).
///
/// Expected flow:
/// - loads page 1 from `GET /api/v1/toys`
/// - debounced search against `q`
/// - category filter uses exact label strings returned by `GET /api/v1/categories`
class CatalogScreen {}
