class QaEntry < ApplicationRecord
  belongs_to :report

  # Enums for the Dropdowns
  enum qa_type: { 
    compaction: 0, 
    concrete_slump: 1, 
    concrete_cylinder: 2, 
    asphalt_temp: 3, 
    nuclear_gauge: 4,
    proof_roll: 5 
  }

  enum result: { 
    qa_pass: 0, 
    qa_fail: 1, 
    qa_pending: 2, 
    qa_n_a: 3 
  }
end