{{flutter_build_config}}

_flutter.loader.load({
  canvasKitBaseUrl: "canvaskit/",
  onEntryPointLoaded: async function(engineInitializer) {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
  },
});
