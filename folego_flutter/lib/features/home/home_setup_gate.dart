import '../../data/models/onboarding_state.dart';

/// Recebimentos futuros não são pré-requisito para consultar a Home.
bool shouldShowFirstUseHome(OnboardingState? setup) =>
    setup != null && !setup.hasAccount;
