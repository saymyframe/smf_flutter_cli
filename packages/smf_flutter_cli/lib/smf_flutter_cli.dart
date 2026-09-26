/// The `smf` command line: the modules it offers, and the terminal, files
/// and processes of the machine it runs on, for the pipeline of
/// `package:smf_pipeline`.
library;

export 'src/cli.dart' show runCli;
export 'src/io/host.dart' show IoHost;
export 'src/io/interruption.dart' show Interruption;
export 'src/modules.dart' show smfModules;
