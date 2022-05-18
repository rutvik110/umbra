import 'dart:async';

import 'package:args/args.dart';
import 'package:mason/mason.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pub_updater/pub_updater.dart';
import 'package:test/test.dart';
import 'package:umbra_cli/src/commands/commands.dart';
import 'package:umbra_cli/src/commands/create/templates/templates.dart';

import '../../../helpers/helpers.dart';

const expectedUsage = [
  // ignore: no_adjacent_strings_in_list
  'Create a new Umbra Shader.\n'
      '\n'
      'Usage: umbra create [arguments]\n'
      '-h, --help                      Print this usage information.\n'
      '-o, --output                    The output directory for the created file.\n'
      '-t, --template                  The template used to create this new shader.\n'
      '\n'
      '          [simple] (default)    Create a simple shader.\n'
      '          [translate]           Create a translating shader.\n'
      '\n'
      'Run "umbra help" to see global options.'
];

class _MockArgResults extends Mock implements ArgResults {}

class _MockLogger extends Mock implements Logger {}

class _MockPubUpdater extends Mock implements PubUpdater {}

class _MockMasonGenerator extends Mock implements MasonGenerator {}

class _FakeDirectoryGeneratorTarget extends Fake
    implements DirectoryGeneratorTarget {}

class _FakeLogger extends Fake implements Logger {}

void main() {
  group('create', () {
    late List<String> progressLogs;
    late Logger logger;

    final generatedFiles = List.filled(
      1,
      const GeneratedFile.created(path: ''),
    );

    setUpAll(() {
      registerFallbackValue(_FakeDirectoryGeneratorTarget());
      registerFallbackValue(_FakeLogger());
    });

    setUp(() {
      progressLogs = <String>[];

      logger = _MockLogger();
      when(() => logger.progress(any())).thenReturn(
        ([_]) {
          if (_ != null) progressLogs.add(_);
        },
      );
    });

    test(
      'help',
      withRunner((commandRunner, logger, platform, cmd, printLogs) async {
        final result = await commandRunner.run(['create', '--help']);
        expect(printLogs, equals(expectedUsage));
        expect(result, equals(ExitCode.success.code));

        printLogs.clear();

        final resultAbbr = await commandRunner.run(['create', '-h']);
        expect(printLogs, equals(expectedUsage));
        expect(resultAbbr, equals(ExitCode.success.code));
      }),
    );

    test(
      'throws UsageException when name is missing',
      withRunner((commandRunner, logger, platform, cmd, printLogs) async {
        const expectedErrorMessage = 'No name specified.';

        final result = await commandRunner.run(['create', '']);
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(expectedErrorMessage)).called(1);
      }),
    );

    test(
      'throws UsageException when output directory does not exist',
      withRunner((commandRunner, logger, platform, cmd, printLogs) async {
        const expectedErrorMessage =
            'Directory "/none/existing" does not exist.';

        final result = await commandRunner.run(
          ['create', 'test', '--output', '/none/existing'],
        );
        expect(result, equals(ExitCode.usage.code));
        verify(() => logger.err(expectedErrorMessage)).called(1);
      }),
    );

    test('completes successfully with correct output', () async {
      final argResults = _MockArgResults();
      final generator = _MockMasonGenerator();
      final command = CreateCommand(
        logger: logger,
        generator: (_) async => generator,
      )..testArgResults = argResults;
      when(() => argResults.rest).thenReturn(['test']);
      when(
        () => generator.generate(
          any(),
          vars: any(named: 'vars'),
          logger: any(named: 'logger'),
        ),
      ).thenAnswer((_) async {
        return generatedFiles;
      });

      final result = await command.run();
      expect(result, equals(ExitCode.success.code));

      verify(() => logger.progress('Creating a Umbra Shader')).called(1);
      expect(progressLogs, equals(['Created a Umbra Shader!']));

      verify(
        () => generator.generate(
          any(that: isA<DirectoryGeneratorTarget>()),
          vars: <String, dynamic>{'name': 'test'},
          logger: logger,
        ),
      ).called(1);
    });

    group('--template', () {
      group('invalid template name', () {
        test(
          'invalid template name',
          withRunner((commandRunner, logger, platform, cmd, printLogs) async {
            const templateName = 'bad-template';
            const expectedErrorMessage =
                '''"$templateName" is not an allowed value for option "template".''';

            final result = await commandRunner.run(
              ['create', 'test', '--template', templateName],
            );
            expect(result, equals(ExitCode.usage.code));
            verify(() => logger.err(expectedErrorMessage)).called(1);
          }),
        );
      });

      group('valid templates names', () {
        Future<void> expectValidTemplateName({
          required String templateName,
          required MasonBundle expectedBundle,
        }) async {
          final argResults = _MockArgResults();
          final generator = _MockMasonGenerator();
          final command = CreateCommand(
            logger: logger,
            generator: (bundle) async {
              expect(bundle, equals(expectedBundle));
              return generator;
            },
          )..testArgResults = argResults;
          when(() => argResults['template'] as String?)
              .thenReturn(templateName);
          when(() => argResults.rest).thenReturn(['test']);
          when(
            () => generator.generate(
              any(that: isA<DirectoryGeneratorTarget>()),
              vars: any(named: 'vars'),
              logger: any(named: 'logger'),
            ),
          ).thenAnswer((_) async {
            return generatedFiles;
          });

          final result = await command.run();
          expect(result, equals(ExitCode.success.code));

          verify(() => logger.progress('Creating a Umbra Shader')).called(1);
          expect(progressLogs, equals(['Created a Umbra Shader!']));

          verify(
            () => generator.generate(
              any(),
              vars: <String, dynamic>{'name': 'test'},
              logger: logger,
            ),
          ).called(1);
        }

        test('simple template', () async {
          await expectValidTemplateName(
            templateName: 'simple',
            expectedBundle: simpleShaderBundle,
          );
        });

        test('translate template', () async {
          await expectValidTemplateName(
            templateName: 'translate',
            expectedBundle: translateShaderBundle,
          );
        });
      });
    });
  });
}