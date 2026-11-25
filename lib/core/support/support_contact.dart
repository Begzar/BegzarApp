import 'package:begzar/core/services/native_url_launcher.dart';
import 'package:flutter/widgets.dart';

/// The support bot every "get help" affordance in the app opens.
const supportTelegramUrl = 'https://t.me/BegzarPremiumBot';

/// The bot, opened on its start screen — how every entry into it arrives.
const supportTelegramLink = '$supportTelegramUrl?start=1';

/// Opens the support chat.
///
/// Lives in core rather than with the premium dialogs that used to own it:
/// opening a Telegram link is not a premium concern, and the error popup
/// offers the same help without knowing anything about subscriptions.
///
/// TODO(#124): [context] and [message] are both ignored — the deep link only
/// carries `start=1`, so the message the caller composed never reaches the
/// chat and the user retypes it.
Future<void> openSupportTelegram(
  BuildContext context, {
  required String message,
}) {
  return NativeUrlLauncher.open(supportTelegramLink);
}
