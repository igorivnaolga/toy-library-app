/// State management for the catalog feature.
///
/// Depending on your chosen stack, this becomes:
/// - a `ChangeNotifier` (Provider), or
/// - a `Notifier` (Riverpod), or
/// - a Cubit/Bloc
///
/// It should own: loading/error flags, current filters, paged results, and refresh.
class CatalogProvider {}
