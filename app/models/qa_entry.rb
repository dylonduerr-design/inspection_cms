class QaEntry < ApplicationRecord
  belongs_to :report
  
  enum qa_type: { density: 0, gradation: 1, smoothness: 2, final_grade: 3, compaction: 4, surface_prep: 5 }
  enum result: { qa_pass: 0, qa_fail: 1, results_pending: 2, info_only: 3 }
end