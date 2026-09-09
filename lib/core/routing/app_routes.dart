/// Named route identifiers for the app's navigation.
///
/// Only the foundation route exists in this phase. Feature modules
/// register their own route names here as they are built, and a real
/// router (e.g. named routes or go_router) is wired up once there is more
/// than one screen to navigate between.
abstract final class AppRoutes {
  static const home = '/';
}
