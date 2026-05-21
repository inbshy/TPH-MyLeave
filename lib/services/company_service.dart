import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/company.dart';
import 'package:tph_myleave/models/company_group.dart';

class CompanyService {
  final _client = SupabaseConfig.client;

  Future<List<CompanyGroup>> fetchCompanyGroups() async {
    final response = await _client
        .from(AppConstants.tableCompanyGroups)
        .select()
        .order('groupName');

    final list = response as List<dynamic>;
    return list
        .map((e) => CompanyGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CompanyGroup> createCompanyGroup(String groupName) async {
    final row = await _client
        .from(AppConstants.tableCompanyGroups)
        .insert({'groupName': groupName.trim()})
        .select()
        .single();
    return CompanyGroup.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<Company>> fetchCompanies() async {
    final response = await _client
        .from(AppConstants.tableCompany)
        .select('company_id, companyName, group_id, company_groups(group_id, groupName)')
        .order('companyName');

    final list = response as List<dynamic>;
    return list
        .map((e) => Company.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Company?> fetchCompanyById(int companyId) async {
    final row = await _client
        .from(AppConstants.tableCompany)
        .select('company_id, companyName, group_id, company_groups(group_id, groupName)')
        .eq('company_id', companyId)
        .maybeSingle();
    if (row == null) return null;
    return Company.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Company> createCompany({
    required String companyName,
    required int groupId,
  }) async {
    final row = await _client
        .from(AppConstants.tableCompany)
        .insert({
          'companyName': companyName.trim(),
          'group_id': groupId,
        })
        .select('company_id, companyName, group_id, company_groups(group_id, groupName)')
        .single();
    return Company.fromJson(Map<String, dynamic>.from(row));
  }

  Future<CompanyGroup> updateCompanyGroup({
    required int groupId,
    required String groupName,
  }) async {
    final row = await _client
        .from(AppConstants.tableCompanyGroups)
        .update({'groupName': groupName.trim()})
        .eq('group_id', groupId)
        .select()
        .single();
    return CompanyGroup.fromJson(Map<String, dynamic>.from(row));
  }

  Future<Company> updateCompany({
    required int companyId,
    required String companyName,
    required int groupId,
  }) async {
    final row = await _client
        .from(AppConstants.tableCompany)
        .update({
          'companyName': companyName.trim(),
          'group_id': groupId,
        })
        .eq('company_id', companyId)
        .select('company_id, companyName, group_id, company_groups(group_id, groupName)')
        .single();
    return Company.fromJson(Map<String, dynamic>.from(row));
  }
}
