/* Headless Lua runner for the fidelity harness (golden differential tests).
 *
 * mGBA 0.10.x builds its Lua scripting engine into libmgba, but only the Qt
 * GUI exposes it (Tools → Scripting…); the SDL frontend has no script entry
 * point at all.  This tiny frontend links the same libmgba and provides the
 * headless entry the harness needs:
 *
 *   mgba-lua-runner -s script.lua [-F maxframes] rom.gb
 *
 * Boot the ROM, attach the scripting context (stdlib + socket + Lua + a
 * stdout console), load the script, then run frames — triggering the same
 * "frame" callback per frame that mCoreThread fires in the GUI (thread.c
 * ADD_CALLBACK(frame)), so callbacks:add("frame", …) scripts run unchanged.
 * The script can end the run early with os.exit() (full luaL_openlibs, so
 * io/os are available for GOLDEN.BIN writing).
 *
 * -F is a watchdog default, not a target: scripts normally decide when to
 * exit; the cap just guarantees an unattended run terminates.
 *
 * Core-boot boilerplate modeled on mGBA's own headless example,
 * src/platform/test/fuzz-main.c (MPL-2.0, as is this file).
 */

#include <mgba/core/blip_buf.h>
#include <mgba/core/config.h>
#include <mgba/core/core.h>
#include <mgba/core/log.h>
#include <mgba/core/scripting.h>
#include <mgba/script/context.h>
#include <mgba-util/table.h>

#include <getopt.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define DEFAULT_MAX_FRAMES 36000 /* 10 minutes of emulated time @60fps */

static volatile sig_atomic_t _exiting = 0;

static void _shutdown(int sig) {
	(void) sig;
	_exiting = 1;
}

/* console:log / warn / error from Lua arrive here (via the attached
 * logger), as does core logging. Print and flush so a crashed/killed run
 * still shows everything the script said. */
static void _log(struct mLogger* logger, int category, enum mLogLevel level,
                 const char* format, va_list args) {
	(void) logger;
	(void) category;
	FILE* out = (level == mLOG_ERROR || level == mLOG_WARN) ? stderr : stdout;
	vfprintf(out, format, args);
	fputc('\n', out);
	fflush(out);
}

static void _findEngine(const char* key, void* value, void* user) {
	(void) key;
	*(struct mScriptEngineContext**) user = value;
}

static void _usage(const char* argv0) {
	fprintf(stderr, "usage: %s -s script.lua [-F maxframes] rom.gb\n", argv0);
}

int main(int argc, char** argv) {
	const char* scriptPath = NULL;
	long maxFrames = DEFAULT_MAX_FRAMES;

	int opt;
	while ((opt = getopt(argc, argv, "s:F:")) != -1) {
		switch (opt) {
		case 's':
			scriptPath = optarg;
			break;
		case 'F':
			maxFrames = strtol(optarg, NULL, 0);
			break;
		default:
			_usage(argv[0]);
			return 1;
		}
	}
	if (optind >= argc || !scriptPath || maxFrames <= 0) {
		_usage(argv[0]);
		return 1;
	}
	const char* romPath = argv[optind];

	signal(SIGINT, _shutdown);
	signal(SIGTERM, _shutdown);

	static struct mLogger logger = { .log = _log };
	mLogSetDefaultLogger(&logger);

	struct mCore* core = mCoreFind(romPath);
	if (!core) {
		fprintf(stderr, "ERROR: no core for %s\n", romPath);
		return 1;
	}
	core->init(core);
	mCoreInitConfig(core, "fidelity-harness");

	/* Rendered pixels must exist for tile/BG state to be inspectable. */
	void* videoBuffer = malloc(256 * 256 * 4);
	core->setVideoBuffer(core, videoBuffer, 256);

	int ret = 1;
	if (!mCoreLoadFile(core, romPath)) {
		fprintf(stderr, "ERROR: cannot load ROM %s\n", romPath);
		goto teardown;
	}
	core->reset(core);

	/* Audio is unconsumed in headless runs; set sane rates and drain per
	 * frame so the blip buffers never overflow (as fuzz-main.c does). */
	blip_set_rates(core->getAudioChannel(core, 0), core->frequency(core), 32768);
	blip_set_rates(core->getAudioChannel(core, 1), core->frequency(core), 32768);

	struct mScriptContext scriptContext;
	mScriptContextInit(&scriptContext);
	mScriptContextAttachStdlib(&scriptContext);
	mScriptContextAttachSocket(&scriptContext);
	mScriptContextRegisterEngines(&scriptContext);
	mScriptContextAttachLogger(&scriptContext, &logger);
	mScriptContextAttachCore(&scriptContext, core); /* after reset: builds the memory map */

	if (!mScriptContextLoadFile(&scriptContext, scriptPath)) {
		fprintf(stderr, "ERROR: script load failed: %s\n", scriptPath);
		goto scriptTeardown;
	}
	/* LoadFile only compiles; the engine must run the chunk explicitly
	 * (mirrors ScriptingController::load: engine->load then engine->run).
	 * Only the Lua engine is registered, so "any engine" is the right one. */
	struct mScriptEngineContext* engine = NULL;
	HashTableEnumerate(&scriptContext.engines, _findEngine, &engine);
	if (!engine || !engine->run(engine)) {
		fprintf(stderr, "ERROR: script run failed: %s\n",
		        engine ? engine->getError(engine) : "no script engine registered");
		goto scriptTeardown;
	}

	for (long frame = 0; frame < maxFrames && !_exiting; ++frame) {
		core->runFrame(core);
		/* Same event mCoreThread maps videoFrameEnded to. */
		mScriptContextTriggerCallback(&scriptContext, "frame");
		blip_clear(core->getAudioChannel(core, 0));
		blip_clear(core->getAudioChannel(core, 1));
	}
	mScriptContextTriggerCallback(&scriptContext, "shutdown");
	ret = 0;

scriptTeardown:
	mScriptContextDetachCore(&scriptContext);
	mScriptContextDeinit(&scriptContext);
	core->unloadROM(core);
teardown:
	mCoreConfigDeinit(&core->config);
	core->deinit(core);
	free(videoBuffer);
	return ret;
}
