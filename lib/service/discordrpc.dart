import 'package:dart_discord_rpc/dart_discord_rpc.dart';

DiscordRPC rpc = DiscordRPC(applicationId: "968618659599753266");

rpcInitialize() {
  rpc.start(autoRegister: true);
  rpc.updatePresence(_defaultPresence);
}

DiscordPresence _defaultPresence = DiscordPresence(
  state: 'No Source',
  details: 'by MindStudio',
  startTimeStamp: DateTime.now().millisecondsSinceEpoch,
  largeImageKey: 'large_image',
  largeImageText: 'NDIScopes by MindStudio',
  smallImageKey: 'rpc_idle',
  smallImageText: 'Idle',
);

rpcUpdate(String? sourceName) {
  _defaultPresence = DiscordPresence(
    details: _defaultPresence.details,
    endTimeStamp: _defaultPresence.endTimeStamp,
    instance: _defaultPresence.instance,
    joinSecret: _defaultPresence.joinSecret,
    largeImageKey: _defaultPresence.largeImageKey,
    largeImageText: _defaultPresence.largeImageText,
    matchSecret: _defaultPresence.matchSecret,
    partyId: _defaultPresence.partyId,
    partySize: _defaultPresence.partySize,
    partySizeMax: _defaultPresence.partySizeMax,
    smallImageKey: sourceName != null ? "rpc_live" : "rpc_idle",
    smallImageText: sourceName != null ? "Receiving Frames" : "Idle",
    spectateSecret: _defaultPresence.spectateSecret,
    startTimeStamp: _defaultPresence.startTimeStamp,
    state: sourceName ?? "No Source",
  );

  rpc.updatePresence(_defaultPresence);
}

rpcDispose() {
  rpc.clearPresence();
  rpc.shutDown();
}
