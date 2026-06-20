"""Minimal stand-in for the SCons `env` object passed to Godot's builder functions.

The CMake build drives Godot's real Python builders (core_builders, modules_builders,
glsl_builders, editor_builders, ...) via run_builder.py. Those builders take an `env`
argument but, per audit, touch it almost never:
  - `editor_builders.make_translations` calls `env.Detect("msgfmt")` (we return "" -> falls
    back to the bundled `.po`/`.mo`, which is fine).
  - the shader builders call `env.NoCache(target)` (a no-op here).

Anything a builder reads that isn't provided raises AttributeError/KeyError with a clear
message, so we learn exactly what to add rather than silently producing wrong output.
"""


class FakeEnv(dict):
    def __getattr__(self, key):
        try:
            return self[key]
        except KeyError as exc:
            raise AttributeError(
                f"FakeEnv has no attribute/key '{key}'. A builder needs it; add it to "
                f"misc/cmake/fake_env.py (or pass it through run_builder.py)."
            ) from exc

    def __setattr__(self, key, value):
        self[key] = value

    # SCons env methods occasionally used by builders.
    def Detect(self, *_args, **_kwargs):
        return ""

    def NoCache(self, *_args, **_kwargs):
        return None
