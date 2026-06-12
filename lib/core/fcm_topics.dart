/// Los nombres de topic FCM solo admiten [a-zA-Z0-9-_.~%].
/// Condominio y casa pueden tener espacios u otros caracteres ("Acacia 21");
/// se reemplazan por "_". DEBE coincidir con safeTopic() del backend
/// (functions/src/notifications.ts).
String fcmTopic(String raw) =>
    raw.replaceAll(RegExp(r'[^a-zA-Z0-9\-_.~%]'), '_');
