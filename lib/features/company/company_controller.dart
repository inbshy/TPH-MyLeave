import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/models/company.dart';
import 'package:tph_myleave/models/company_group.dart';
import 'package:tph_myleave/services/company_service.dart';

final companyServiceProvider =
    Provider<CompanyService>((ref) => CompanyService());

final companiesProvider = FutureProvider<List<Company>>((ref) async {
  return ref.watch(companyServiceProvider).fetchCompanies();
});

final companyGroupsProvider = FutureProvider<List<CompanyGroup>>((ref) async {
  return ref.watch(companyServiceProvider).fetchCompanyGroups();
});
