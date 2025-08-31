// Copyright 2025 SayMyFrame. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:smf_flutter_cli/commands/smf_command_runner.dart';

Future<void> main(List<String> arguments) async {
  try {
    await SMFCommandRunner().run(arguments);
  } on UsageException catch (e) {
    exit(64);
  } on FormatException catch (e) {
    exit(64);
  } on ProcessException catch (e) {
    exit(1);
  } on Exception catch (e) {
    exit(1);
  }
}
