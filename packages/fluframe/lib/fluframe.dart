/// fluFrame CLI — generates production-ready Flutter apps from the
/// fluFrame boilerplate.
///
/// This file exists to be resolved, not imported. `template_source.dart`
/// asks `Isolate.resolvePackageUri` for `package:fluframe/fluframe.dart`
/// to find the package root, and from there the bundled `templates/app`;
/// the URI has to name a real file for that to work.
///
/// fluframe's public surface is its executable — `fluframe create`,
/// `doctor`, `add`, `upgrade` — and the CLI is what its tests, its
/// changelog and its semver promises describe. It used to re-export eight
/// libraries from `src/`, which offered a Dart API that nothing imported,
/// nothing documented and no test exercised: every symbol in it was free
/// to change under anyone who had found it, in a patch release. Rather
/// than freeze a surface nobody asked for, this declares none.
///
/// If you want a library API for any of this, please open an issue —
/// https://github.com/JoGyoungJun/fluFrame/issues — and say which part
/// and why. That is a design conversation, not an export line.
library;
