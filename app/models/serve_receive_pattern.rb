class ServeReceivePattern < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum :origin, { serve: 0, receive: 1 }, prefix: :origin
  enum :serve_length, { long: 0, half_long: 1, short: 2 }
  enum :decided_at, { attack_ball: 0, follow_ball: 1, rally: 2 }
  enum :attack_style, {
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
    service_ace: 22,
    receive_ace: 23,
    receive_miss: 24
  }, prefix: :attack

  # receive_style は attack_style と同一のキー・整数マッピングを持つため enum 定義は行わない。
  # 表示時は Score.human_enum_name(:batting_style, key) を利用すること。
  RECEIVE_STYLE_VALUES = {
    fore_drive_vs_topspin: 15, back_drive_vs_topspin: 16,
    fore_drive_vs_backspin: 17, back_drive_vs_backspin: 18,
    fore_push: 4, back_push: 5,
    fore_stop: 6, back_stop: 7,
    fore_flick: 8, back_flick: 9,
    chiquita: 10, fore_block: 11,
    back_block: 12, fore_counter: 13,
    back_counter: 14,
    fore_smash: 19, back_smash: 20,
    net_or_edge: 21
  }.freeze

  SERVE_SPINS = { backspin: 0, topspin: 1, no_spin: 2, pro_sidespin: 3, anti_sidespin: 4 }.freeze
  SERVE_SPIN_NAMES_JA = {
    0 => '下回転', 1 => '上回転', 2 => 'ナックル', 3 => '順横回転', 4 => '逆横回転'
  }.freeze

  validates :origin, :attack_style, :decided_at, :game_number, :sequence_number, presence: true
  validates :won, inclusion: { in: [true, false] }

  def self.allowed_attack_styles
    attack_styles.keys
  end
end
