class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", foreign_key: "player_id"
  belongs_to :opponent, class_name: "Player", foreign_key: "opponent_id"
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games
  attr_accessor :player_name, :opponent_name
  attr_accessor :post_to_x

  validates :match_date, presence: true
  validates :match_name, presence: true
  validates :memo, length: { maximum: 500, message: "は500文字以内で入力してください" }, allow_blank: true
  validate :validate_player_and_opponent_names

  def validate_player_and_opponent_names
    if player_name.blank?
      errors.add(:player_name, "を入力してください")
    end

    if opponent_name.blank?
      errors.add(:opponent_name, "を入力してください")
    end
  end

  def self.ransackable_attributes(auth_object = nil)
    ["match_name", "player_id", "opponent_id"]
  end

  def self.ransackable_associations(auth_object = nil)
    ["player"]
  end

    # Ransackのカスタムスコープを定義
  def self.ransackable_scopes(auth_object = nil)
    [:opponent_player_name_cont]
  end

  def self.opponent_player_name_cont(query)
    joins(:opponent).where("players.player_name LIKE ?", "%#{query}%")
  end
end
