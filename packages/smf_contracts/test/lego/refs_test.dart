import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

const _file = ImportRef.app('core/analytics/analytics_service.dart');

void main() {
  group('TypeRef', () {
    test('refers to a type by name, after the prefix of its import', () {
      expect(
        const TypeRef('AnalyticsService', import: _file).code,
        'AnalyticsService',
      );
      expect(
        const TypeRef(
          'FirebaseAnalytics',
          import: ImportRef('package:firebase_analytics/x.dart', prefix: 'fa'),
        ).code,
        'fa.FirebaseAnalytics',
      );
      expect(const TypeRef('int').code, 'int');
      expect('${const TypeRef('int')}', 'int');
    });

    test('is the same type whatever prefix or show imports its file', () {
      const plain = TypeRef('Dio', import: ImportRef('package:dio/dio.dart'));
      const prefixed = TypeRef(
        'Dio',
        import: ImportRef('package:dio/dio.dart', prefix: 'dio', show: ['Dio']),
      );

      expect(prefixed, plain);
      expect(prefixed.hashCode, plain.hashCode);
      expect(const ServiceRef(prefixed), const ServiceRef(plain));
      expect(prefixed.code, 'dio.Dio');
      expect(plain.codeWith('http'), 'http.Dio');
      expect(
        plain,
        isNot(const TypeRef('Dio', import: ImportRef.app('dio.dart'))),
      );
    });

    test('is the same type when the name and import are', () {
      expect(
        const TypeRef('A', import: _file),
        TypeRef('A', import: ImportRef.app(_file.uri)),
      );
      expect(
        const TypeRef('A', import: _file).hashCode,
        TypeRef('A', import: ImportRef.app(_file.uri)).hashCode,
      );
      expect(const TypeRef('A', import: _file), isNot(const TypeRef('A')));
      expect(const TypeRef('A'), isNot(const TypeRef('B')));
    });

    test('rejects names that are not public type names', () {
      expect(const TypeRef('AnalyticsService').problems(), isEmpty);
      for (final name in ['List<int>', '_Private', 'class', '']) {
        expect(TypeRef(name).problems(), hasLength(1), reason: name);
      }
      expect(
        const TypeRef('A', import: ImportRef('lib/a.dart')).problems(),
        hasLength(1),
      );
    });
  });

  group('FunctionRef', () {
    test('refers to a function by name, after the prefix of its import', () {
      const plain = FunctionRef('disposeClient', import: _file);
      const prefixed = FunctionRef(
        'dispose',
        import: ImportRef('package:x/x.dart', prefix: 'x'),
      );

      expect(plain.code, 'disposeClient');
      expect(prefixed.code, 'x.dispose');
      expect(prefixed.codeWith(null), 'dispose');
      expect('$plain', 'disposeClient()');
      expect(plain.problems(), isEmpty);
      expect(
        const FunctionRef('_private', import: _file).problems(),
        hasLength(1),
      );
    });
  });

  group('FactoryRef', () {
    test('refers to a function and the services it takes', () {
      const factory = FactoryRef(
        'createGreeter',
        import: ImportRef('package:x/x.dart', prefix: 'x'),
        deps: [ServiceRef(TypeRef('AnalyticsService', import: _file))],
      );

      expect(factory.code, 'x.createGreeter');
      expect(factory.codeWith('impl0'), 'impl0.createGreeter');
      expect('$factory', 'createGreeter()');
      expect(factory.problems(), isEmpty);
    });

    test('reports its own problems and those of its services', () {
      const factory = FactoryRef(
        'new',
        import: _file,
        deps: [ServiceRef(TypeRef('A'), instanceName: '')],
      );

      expect(factory.problems(), hasLength(2));
    });
  });

  group('ServiceRef', () {
    test('is a type with an optional instance name', () {
      const plain = ServiceRef(TypeRef('Storage', import: _file));
      const named =
          ServiceRef(TypeRef('Storage', import: _file), instanceName: 'secure');

      expect('$plain', 'Storage');
      expect('$named', 'Storage "secure"');
      expect(plain, isNot(named));
      expect(
        named,
        const ServiceRef(
          TypeRef('Storage', import: _file),
          instanceName: 'secure',
        ),
      );
      expect(named.problems(), isEmpty);
    });
  });
}
