class AiUsageLog < ApplicationRecord
  FEATURES = %w[match_advice serve_receive_advice monthly_report].freeze

  belongs_to :user, optional: true

  validates :feature, presence: true, inclusion: { in: FEATURES }
end
