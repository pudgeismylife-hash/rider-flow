class FirebaseConstants {
  FirebaseConstants._();

  // Root level
  static const String companiesCollection = 'companies';

  // Path Builders for Multi-Tenancy Isolation
  static String companyPath(String companyId) => 
      '$companiesCollection/$companyId';

  static String branchesCollection(String companyId) => 
      '${companyPath(companyId)}/branches';

  static String branchPath(String companyId, String branchId) => 
      '${branchesCollection(companyId)}/$branchId';

  // Subcollections scoped under Branch level
  static String usersCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/users';

  static String userPath(String companyId, String branchId, String uid) => 
      '${usersCollection(companyId, branchId)}/$uid';

  static String ridersCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/riders';

  static String riderPath(String companyId, String branchId, String riderId) => 
      '${ridersCollection(companyId, branchId)}/$riderId';

  static String attendanceCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/attendance';

  static String attendancePath(String companyId, String branchId, String attendanceId) => 
      '${attendanceCollection(companyId, branchId)}/$attendanceId';

  static String ledgerCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/ledger';

  static String transactionPath(String companyId, String branchId, String transactionId) => 
      '${ledgerCollection(companyId, branchId)}/$transactionId';

  static String closingsCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/closings';

  static String closingPath(String companyId, String branchId, String closingId) => 
      '${closingsCollection(companyId, branchId)}/$closingId';

  static String notificationsCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/notifications';

  static String notificationPath(String companyId, String branchId, String notificationId) => 
      '${notificationsCollection(companyId, branchId)}/$notificationId';

  static String activityLogsCollection(String companyId, String branchId) => 
      '${branchPath(companyId, branchId)}/activity_logs';

  static String activityLogPath(String companyId, String branchId, String logId) => 
      '${activityLogsCollection(companyId, branchId)}/$logId';
}
