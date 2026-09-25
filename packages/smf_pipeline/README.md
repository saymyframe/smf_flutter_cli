[![Quality Gate Status](https://sonarcloud.io/api/project_badges/measure?project=saymyframe_smf_flutter_cli&metric=alert_status)](https://sonarcloud.io/summary/new_code?id=saymyframe_smf_flutter_cli)

# smf_pipeline

The generation pipeline of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli): it selects modules, checks their contributions against the roles they declare, and generates a Flutter app from them.

The pipeline knows no concrete module or role. It depends only on the core of the lego model, `package:smf_contracts/lego_core.dart`, and receives the modules and the machine it runs on from the CLI.

Most users use it through the SMF CLI.

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_pipeline) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See [LICENSE](LICENSE).
