@IsTest
private class PropfocusInboundWritebackServiceTest {
  private static Lead makeLead() {
    return PropfocusTestUtil.createLead('Writeback Buyer');
  }

  @IsTest
  static void applyWriteback_updatesLeadAndChildRecords() {
    Lead ld = makeLead();
    Map<String, Object> payload = new Map<String, Object>{
      'lead_data' => new Map<String, Object>{
        'buyer_name' => 'Updated Buyer',
        'lead_status' => 'Working - Contacted',
        'lead_source' => 'PropFocus',
        'primary_project_name' => 'Project Alpha'
      },
      'call_logs' => new List<Object>{
        new Map<String, Object>{
          'duration' => '120',
          'disposition' => 'Answered',
          'call_time' => '2026-05-26T10:15:00.000Z',
          'recording_url' => 'https://example.test/rec/1'
        }
      },
      'site_visit' => new Map<String, Object>{
        'site_visit_number' => 'SV-1001',
        'site_visit_type' => 'Physical',
        'site_visit_status' => 'Scheduled',
        'site_visit_datetime' => '2026-05-27T14:00:00.000Z',
        'sv_team' => 'Team A',
        'manager' => new Map<String, Object>{
          'name' => 'Manager One',
          'phone' => '9999999999',
          'email' => 'manager@example.com'
        }
      },
      'lead_history' => new List<Object>{
        new Map<String, Object>{
          'field_changed' => 'Status',
          'old_value' => 'Open - Not Contacted',
          'new_value' => 'Working - Contacted',
          'change_date' => '2026-05-26T09:00:00.000Z',
          'changed_by' => 'PropFocus'
        }
      }
    };

    Test.startTest();
    PropfocusInboundWritebackService.WritebackResult result = PropfocusInboundWritebackService.applyWriteback(
      ld.Id,
      payload
    );
    Test.stopTest();

    System.assertEquals(true, result.leadUpdated);
    System.assertEquals(1, result.callLogsCreated);
    System.assertEquals(1, result.historyRowsCreated);
    System.assertEquals(true, result.siteVisitSynced);

    Lead updatedLead = [
      SELECT Status, LeadSource
      FROM Lead
      WHERE Id = :ld.Id
    ];
    System.assertEquals('Working - Contacted', updatedLead.Status);
    System.assertEquals('PropFocus', updatedLead.LeadSource);

    System.assertEquals(
      1,
      [SELECT COUNT() FROM Propfocus_Call_Log__c WHERE Lead__c = :ld.Id]
    );
    System.assertEquals(
      1,
      [SELECT COUNT() FROM Propfocus_Sync_History__c WHERE Lead__c = :ld.Id]
    );
    System.assertEquals(
      1,
      [
        SELECT COUNT()
        FROM Propfocus_Site_Visit_Sync__c
        WHERE Lead__c = :ld.Id AND Site_Visit_Number__c = 'SV-1001'
      ]
    );
  }

  @IsTest
  static void applyWriteback_rejectsMismatchedLeadId() {
    Lead ld = makeLead();
    Map<String, Object> payload = new Map<String, Object>{
      'lead_data' => new Map<String, Object>{
        'salesforce_lead_id' => '00Q000000000000'
      }
    };

    Boolean failedAsExpected = false;
    Test.startTest();
    try {
      PropfocusInboundWritebackService.applyWriteback(ld.Id, payload);
    } catch (PropFocusServiceException e) {
      failedAsExpected = true;
      System.assert(e.getMessage().contains('salesforce_lead_id'));
    }
    Test.stopTest();

    System.assertEquals(true, failedAsExpected);
  }

  @IsTest
  static void hasWritebackPayload_detectsNestedSections() {
    Map<String, Object> payload = new Map<String, Object>{
      'call_logs' => new List<Object>{
        new Map<String, Object>{ 'duration' => '30' }
      }
    };

    System.assertEquals(
      true,
      PropfocusInboundWritebackService.hasWritebackPayload(payload)
    );
    System.assertEquals(
      false,
      PropfocusInboundWritebackService.hasWritebackPayload(
        new Map<String, Object>()
      )
    );
  }

  @IsTest
  static void siteVisitUpsert_updatesExistingByNumber() {
    Lead ld = makeLead();
    Map<String, Object> firstPayload = new Map<String, Object>{
      'site_visit' => new Map<String, Object>{
        'site_visit_number' => 'SV-2001',
        'site_visit_status' => 'Scheduled'
      }
    };
    Map<String, Object> secondPayload = new Map<String, Object>{
      'site_visit' => new Map<String, Object>{
        'site_visit_number' => 'SV-2001',
        'site_visit_status' => 'Completed'
      }
    };

    Test.startTest();
    PropfocusInboundWritebackService.applyWriteback(ld.Id, firstPayload);
    PropfocusInboundWritebackService.applyWriteback(ld.Id, secondPayload);
    Test.stopTest();

    List<Propfocus_Site_Visit_Sync__c> rows = [
      SELECT Site_Visit_Status__c
      FROM Propfocus_Site_Visit_Sync__c
      WHERE Lead__c = :ld.Id AND Site_Visit_Number__c = 'SV-2001'
    ];
    System.assertEquals(1, rows.size());
    System.assertEquals('Completed', rows[0].Site_Visit_Status__c);
  }
}
