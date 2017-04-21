class User < ApplicationRecord
  rolify
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :lockable, :timeoutable,
         :omniauthable, :omniauth_providers => [:facebook]

  mount_uploader :image, ImageUploader

  after_create :assign_default_role
  has_many :participation_requests, :class_name => 'ParticipationRequest', foreign_key: 'participant_id'
  has_many :accepted_participations, :class_name => 'ParticipationRequest', foreign_key: 'acceptor_id'
  has_many :participations, :through => :participation_requests
  has_many :notes, :class_name => 'Note', foreign_key: 'to_id'
  has_many :submitted_notes, :class_name => 'Note', foreign_key: 'from_id'
  belongs_to :year

  attr_accessor :login

  validates_format_of :username, with: /^[a-zA-Z0-9_\.]*$/, :multiline => true
  validates :username,
            :presence => true,
            :uniqueness => {
                :case_sensitive => false
            }

  def full_name
    "#{first_name} #{last_name}"
  end

  def confirmed_points
    if participation_requests.any? or notes.any?
      participation_requests.confirmed.map {|p| p.participation.points}.inject(:+)  + notes.visible.map {|n|n.points}.inject(:+)
    else
      0
    end
  end

  def all_points
      participations.map {|p| p.points}.inject(:+) + notes.visible.map {|n|n.points}.inject(:+)
  end


  def self.from_omniauth(auth)
    where(provider: auth.provider, uid: auth.uid).first_or_create do |user|
      user.provider = auth.provider
      user.uid = auth.uid
      user.email = auth.info.email
      user.first_name = auth.info.first_name
      user.last_name = auth.info.last_name
      user.password = Devise.friendly_token[0, 20]
    end
  end

  def assign_default_role
    self.add_role(:fuksi) if self.roles.blank?
  end

  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    if login = conditions.delete(:login)
      where(conditions.to_hash).where(["lower(username) = :value OR lower(email) = :value", { :value => login.downcase }]).first
    elsif conditions.has_key?(:username) || conditions.has_key?(:email)
      where(conditions.to_hash).first
    end
  end

end
