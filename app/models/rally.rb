class Rally < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum :winner, { player: 0, opponent: 1 }
  enum :point_type, { normal: 0, own_error: 1 }
  enum :batting_style, {
    serve: 0, receive: 1,
    fore_drive_vs_topspin: 15, back_drive_vs_topspin: 16,
    fore_drive_vs_backspin: 17, back_drive_vs_backspin: 18,
    fore_push: 4, back_push: 5,
    fore_stop: 6, back_stop: 7,
    fore_flick: 8, back_flick: 9,
    chiquita: 10, fore_block: 11,
    back_block: 12, fore_counter: 13,
    back_counter: 14,
    fore_smash: 19, back_smash: 20,
    net_or_edge: 21,
    lobbing: 22, serve_miss: 23
  }

  validates :winner, presence: true
  validates :batting_style, presence: true
  validates :game_number, presence: true
  validates :sequence_number, presence: true
  validate :own_error_only_for_opponent_win

  private

  # 自分の凡ミスは相手の得点としてのみ記録できる
  def own_error_only_for_opponent_win
    errors.add(:point_type, :invalid) if own_error? && !opponent?
  end
end
