import 'package:get_it/get_it.dart';
import 'package:nemoai/app/core/utils/utils.dart';
import 'package:nemoai/app/data/providers/viewmodel/auth_view_model.dart';
import 'package:nemoai/app/data/providers/viewmodel/onboarding_view_model.dart';
import 'package:nemoai/app/data/providers/viewmodel/topic_summarizer_view.dart';
import '../../data/middleware/api_services.dart';
import '../../data/providers/viewmodel/exam_prep_view_model.dart';
import '../../data/providers/viewmodel/theme_model.dart';

final locator = GetIt.instance;
setUpLocator() {
  locator.registerLazySingleton(() => ThemeModel());
  locator.registerLazySingleton(() => ExamPrepViewModel());
  locator.registerLazySingleton(() => TopicSummarizerView());

  locator.registerLazySingleton(() => GoogleGenerativeServices());
  locator.registerLazySingleton(() => AuthViewModel());
  locator.registerLazySingleton(() => AppUtils());
  locator.registerLazySingleton(() => OnboardingViewModel());
}
