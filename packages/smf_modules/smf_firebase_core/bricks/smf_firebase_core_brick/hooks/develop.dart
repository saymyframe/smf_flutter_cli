import 'package:mason/mason.dart';

import 'pre_gen.dart' as pre_gen;

void main() async {
  const testPath = '/Users/ybeshkarov/gen/app';
  final vars = <String, dynamic>{
    'working_dir': testPath,
  };

  pre_gen.run(MyHook(vars));
}

class MyHook extends HookContext {
  MyHook(this.vars);

  @override
  Map<String, dynamic> vars;

  @override
  Logger get logger => Logger();
}
