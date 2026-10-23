import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/odoo_session_manager.dart';
import '../data/company_local_datasource.dart';

// Using raw maps for companies to avoid model dependency and ensure UI compatibility

class CompanyProvider extends ChangeNotifier {
  final CompanyLocalDataSource _localDataSource;

  CompanyProvider({CompanyLocalDataSource? localDataSource})
      : _localDataSource = localDataSource ?? CompanyLocalDataSource();

  List<Map<String, dynamic>> _companies = [];
  int? _selectedCompanyId;
  // Multi-company selection for request context (allowed_company_ids)
  List<int> _selectedAllowedCompanyIds = [];
  bool _loading = false;
  bool _switching = false;
  String? _error;

  List<Map<String, dynamic>> get companies => _companies;
  int? get selectedCompanyId => _selectedCompanyId;
  List<int> get selectedAllowedCompanyIds => _selectedAllowedCompanyIds;
  bool get isLoading => _loading;
  bool get isSwitching => _switching;
  String? get error => _error;

  Map<String, dynamic>? get selectedCompany {
    if (_selectedCompanyId == null) return null;
    try {
      return _companies.firstWhere((c) => c['id'] == _selectedCompanyId);
    } catch (e) {
      return null;
    }
  }

  /// Update the selected allowed companies for RPC context injection.
  /// This does not change the active company; it controls allowed_company_ids.
  Future<void> setAllowedCompanies(List<int> allowedIds) async {
    // Filter to companies available to the user
    final availableIds = _companies.map((c) => c['id'] as int).toSet();
    final filtered = allowedIds
        .where((id) => availableIds.contains(id))
        .toList();
    // Ensure active company is present
    if (_selectedCompanyId != null && !filtered.contains(_selectedCompanyId)) {
      filtered.add(_selectedCompanyId!);
    }
    _selectedAllowedCompanyIds = filtered;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    // Update session context
    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }
    notifyListeners();
  }

  /// Called on logout / account switch so the outgoing account's
  /// companies, selection, and cached state don't leak into the next session.
  void reset() {
    _companies = [];
    _selectedCompanyId = null;
    _selectedAllowedCompanyIds = [];
    _loading = false;
    _switching = false;
    _error = null;
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) {
        // No session -> show local cache if available
        _companies = await _localDataSource.getAllCompanies();
        _selectedCompanyId = null;
        _loading = false;
        notifyListeners();
        return;
      }

      List<int> companyIds = [];
      int? currentCompanyId;
      Map<int, String> companyNames = {};

      // 1) Try to use session info first as it's more accurate for multi-company
      final sessionInfo = await OdooSessionManager.getSessionInfo();
      if (sessionInfo != null) {
        // Always try to get top-level company_id first - it's the most reliable "active" indicator
        if (sessionInfo['company_id'] != null) {
          currentCompanyId = sessionInfo['company_id'] is int
              ? sessionInfo['company_id']
              : int.tryParse(sessionInfo['company_id'].toString());
        }

        // Try to parse user_companies for additional context (Odoo 17/18)
        if (sessionInfo['user_companies'] != null) {
          try {
            final userCompaniesRaw = sessionInfo['user_companies'];
            if (userCompaniesRaw is Map) {
              final allowedRaw = userCompaniesRaw['allowed_companies'];
              if (allowedRaw is Map) {
                for (var entry in allowedRaw.entries) {
                  final id = int.tryParse(entry.key.toString()) ?? -1;
                  if (id > 0) {
                    companyIds.add(id);
                    final companyData = entry.value;
                    if (companyData is Map) {
                      companyNames[id] = companyData['name']?.toString() ?? 'Company $id';
                    }
                  }
                }
              }
              // current_company: [id, name] (fallback if top-level company_id was null)
              if (currentCompanyId == null) {
                final currentRaw = userCompaniesRaw['current_company'];
                if (currentRaw is List && currentRaw.isNotEmpty) {
                  currentCompanyId = currentRaw[0] is int ? currentRaw[0] : int.tryParse(currentRaw[0].toString());
                } else if (currentRaw is int) {
                  currentCompanyId = currentRaw;
                }
              }
            }
          } catch (_) {}
        }
      }

      if (companyIds.isEmpty) {
        // Fallback to res.users read (original logic)
        final userRes = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'res.users',
          'method': 'read',
          'args': [
            [session.userId],
            ['company_id', 'company_ids'],
          ],
          'kwargs': {},
        });

        if (userRes is List && userRes.isNotEmpty) {
          final row = userRes.first as Map<String, dynamic>;
          if (row['company_ids'] is List) {
            final raw = row['company_ids'] as List;
            companyIds = raw.whereType<int>().toList();
          }
          if (row['company_id'] is List && (row['company_id'] as List).isNotEmpty) {
            currentCompanyId = (row['company_id'] as List).first as int?;
          }
        }
      }

      if (companyIds.isEmpty) {
        _companies = [];
        _selectedCompanyId = currentCompanyId;
        // Clear local cache because server says none
        _loading = false;
        notifyListeners();
        return;
      }

      // If session_info gave us company names, use them directly
      if (companyNames.isNotEmpty) {
        _companies = companyNames.entries
            .map((e) => <String, dynamic>{'id': e.key, 'name': e.value})
            .toList()
          ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      } else {
        // Fallback: fetch from res.company
        final companiesRes = await OdooSessionManager.safeCallKwWithoutCompany({
          'model': 'res.company',
          'method': 'search_read',
          'args': [
            [
              ['id', 'in', companyIds],
            ],
          ],
          'kwargs': {
            'fields': ['id', 'name'],
            'order': 'name asc',
          },
        });

        final serverCompanies = (companiesRes is List)
            ? companiesRes.cast<Map<String, dynamic>>()
            : <Map<String, dynamic>>[];

        _companies = serverCompanies;
      }

      // Cache the freshly fetched companies for offline use.
      await _localDataSource.putAllCompanies(_companies);

      // Restore selection from SharedPreferences and ensure invariants
      final prefs = await SharedPreferences.getInstance();
      final restoredId = prefs.getInt('selected_company_id');
      final pendingId = prefs.getInt('pending_company_id');
      final restoredAllowed =
          prefs
              .getStringList('selected_allowed_company_ids')
              ?.map((e) => int.tryParse(e) ?? -1)
              .where((e) => e > 0)
              .toList() ??
          [];

      // Selected company precedence: pending -> server current -> restored -> first
      int? desiredId =
          pendingId ?? currentCompanyId ?? restoredId ?? (companyIds.isNotEmpty ? companyIds.first : null);
      _selectedCompanyId = desiredId;

      // Allowed companies matching server-side session:
      // We prioritize the server's CURRENT active company as the ONLY marked one by default to avoid over-selection.
      if (currentCompanyId != null) {
        _selectedAllowedCompanyIds = [currentCompanyId];
      } else {
        // Fallback: If server didn't give a current, use first available or restored
        final restoredValid = restoredAllowed.where((id) => companyIds.contains(id)).toList();
        List<int> defaultAllowed = (companyIds.isNotEmpty) ? [companyIds.first] : [];
        _selectedAllowedCompanyIds = restoredValid.isNotEmpty ? restoredValid : defaultAllowed;
      }

      // Enforce invariants: ensure we always have a valid selected company.
      if (_selectedCompanyId == null || !companyIds.contains(_selectedCompanyId)) {
        if (companyIds.isNotEmpty) {
          _selectedCompanyId = companyIds.first;
        }
      }

      // Ensure allowed list includes the active company and persist immediately
      if (_selectedCompanyId != null && !_selectedAllowedCompanyIds.contains(_selectedCompanyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, _selectedCompanyId!];
      }

      // Ensure local session and prefs match our finalized decision
      if (_selectedCompanyId != null) {
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setInt('selected_company_id', _selectedCompanyId!);
        await prefs2.setStringList(
          'selected_allowed_company_ids',
          _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
        );

        await OdooSessionManager.updateCompanySelection(
          companyId: _selectedCompanyId!,
          allowedCompanyIds: _selectedAllowedCompanyIds,
        );
      }

      // Try to apply pending switch online if it wasn't already matched by server
      if (pendingId != null && companyIds.contains(pendingId) && pendingId != currentCompanyId) {
        try {
          List<int> pendingAllowed = _selectedAllowedCompanyIds;
          if (!pendingAllowed.contains(pendingId)) {
            pendingAllowed = [...pendingAllowed, pendingId];
          }
          await _applyCompanyOnServer(session.userId, pendingId, pendingAllowed);
          await OdooSessionManager.updateCompanySelection(
            companyId: pendingId,
            allowedCompanyIds: pendingAllowed,
          );
          await OdooSessionManager.refreshSessionInfo();
          await (await SharedPreferences.getInstance()).remove('pending_company_id');
        } catch (_) {}
      }
    } catch (e) {
      // Network/API failed -> fallback to local DB
      try {
        if (_companies.isEmpty) {
          _companies = await _localDataSource.getAllCompanies();
        }
        if (_companies.isEmpty) {
          _error = e.toString();
        }
      } catch (_) {
        _error = e.toString();
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Refresh only the companies list from the server/cache without altering
  /// current selection or allowed companies. Use after switching company to
  /// avoid race conditions that reset selection.
  Future<void> refreshCompaniesList() async {
    _loading = true;
    notifyListeners();

    try {
      // Try server first
      final list = await OdooSessionManager.getAllowedCompaniesList();
      if (list.isNotEmpty) {
        _companies = list;
      } else {
        // Fallback to local cache
      }
    } catch (_) {
      // Fallback to local cache on any error
      try {
      } catch (_) {}
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> switchCompany(int companyId) async {
    if (_selectedCompanyId == companyId) return true;
    bool appliedImmediately = false;
    try {
      _switching = true;
      _error = null;
      notifyListeners();
      final session = await OdooSessionManager.getCurrentSession();
      if (session == null) {
        // Persist as pending and as selected for local context injection
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('selected_company_id', companyId);
        await prefs.setInt('pending_company_id', companyId);
        _selectedCompanyId = companyId;
        // Ensure active company is part of allowed selection
        if (!_selectedAllowedCompanyIds.contains(companyId)) {
          _selectedAllowedCompanyIds = [
            ..._selectedAllowedCompanyIds,
            companyId,
          ];
          await prefs.setStringList(
            'selected_allowed_company_ids',
            _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
          );
        }
        notifyListeners();
        return false;
      }

      try {
        // Build the final allowed list: current allowed + new active company
        List<int> finalAllowed = [..._selectedAllowedCompanyIds];
        if (!finalAllowed.contains(companyId)) {
          finalAllowed.add(companyId);
        }
        // Write both company_id and company_ids (allowed list) to the backend
        await _applyCompanyOnServer(session.userId, companyId, finalAllowed);
        // Update local session context to match what we just wrote
        await OdooSessionManager.updateCompanySelection(
          companyId: companyId,
          allowedCompanyIds: finalAllowed,
        );
        // Refresh session info (lightweight - no re-auth) to pick up server changes
        await OdooSessionManager.refreshSessionInfo();
        appliedImmediately = true;
        // Clear any previous pending
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_company_id');
      } catch (_) {
        // Queue as pending if failed (likely offline)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('pending_company_id', companyId);
        appliedImmediately = false;
        // Update local session selection for offline context injection
        List<int> allowed = _selectedAllowedCompanyIds;
        if (!allowed.contains(companyId)) {
          allowed = [...allowed, companyId];
        }
        await OdooSessionManager.updateCompanySelection(
          companyId: companyId,
          allowedCompanyIds: allowed,
        );
      }

      // Persist selection for context injection regardless of server status
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('selected_company_id', companyId);
      // Ensure active company is included in allowed selection
      if (!_selectedAllowedCompanyIds.contains(companyId)) {
        _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
      }
      await prefs.setStringList(
        'selected_allowed_company_ids',
        _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
      );

      // Update local selection and notify
      _selectedCompanyId = companyId;
      notifyListeners();

      // Refresh companies list without touching current selection
      await refreshCompaniesList();
      return appliedImmediately;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    } finally {
      _switching = false;
      notifyListeners();
    }
  }

  Future<void> _applyCompanyOnServer(
      int userId, int companyId, List<int> allowedIds) async {
    // Ensure the active company is always in the allowed list
    await OdooSessionManager.safeCallKwWithoutCompany({
      'model': 'res.users',
      'method': 'write',
      'args': [
        [userId],
        {
          'company_id': companyId,
          // IMPORTANT: We NO LONGER write to 'company_ids' here.
          // 'company_ids' controls a user's PERMANENT access to companies.
          // Session selection is handled by passing 'allowed_company_ids' in the context.
        },
      ],
      'kwargs': {},
    });
  }

  /// Toggle a company in the allowed companies list
  /// The active company cannot be removed from allowed companies
  Future<void> toggleAllowedCompany(int companyId) async {
    if (_selectedAllowedCompanyIds.contains(companyId)) {
      // Cannot remove active company from allowed companies
      if (companyId == _selectedCompanyId) {
        return;
      }
      _selectedAllowedCompanyIds = _selectedAllowedCompanyIds
          .where((id) => id != companyId)
          .toList();
    } else {
      _selectedAllowedCompanyIds = [..._selectedAllowedCompanyIds, companyId];
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'selected_allowed_company_ids',
      _selectedAllowedCompanyIds.map((e) => e.toString()).toList(),
    );

    // Update session context
    if (_selectedCompanyId != null) {
      await OdooSessionManager.updateCompanySelection(
        companyId: _selectedCompanyId!,
        allowedCompanyIds: _selectedAllowedCompanyIds,
      );
    }

    notifyListeners();
  }

  /// Select all available companies as allowed companies
  Future<void> selectAllCompanies() async {
    final allIds = _companies.map((c) => c['id'] as int).toList();
    await setAllowedCompanies(allIds);
  }

  /// Deselect all companies except the active company
  Future<void> deselectAllCompanies() async {
    if (_selectedCompanyId != null) {
      await setAllowedCompanies([_selectedCompanyId!]);
    }
  }

  /// Check if a company is in the allowed companies list
  bool isCompanyAllowed(int companyId) {
    return _selectedAllowedCompanyIds.contains(companyId);
  }
}
