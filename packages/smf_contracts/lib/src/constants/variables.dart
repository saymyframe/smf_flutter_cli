import 'package:smf_contracts/smf_contracts.dart';

/// Key of the template variable that holds the generated project's root
/// directory.
///
/// The CLI sets it to the output directory, and its pre-generation hook then
/// points it at `<output>/<app_name>`. Brick hooks read it to run tools
/// inside the project, and [DslContext.projectRootPath] is taken from it.
const kWorkingDirectory = 'working_dir';
