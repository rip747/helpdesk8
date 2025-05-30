# == Schema Information
#
# Table name: posts
#
#  id          :integer          not null, primary key
#  topic_id    :integer
#  user_id     :integer
#  body        :text
#  kind        :string
#  active      :boolean          default(TRUE)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  points      :integer          default(0)
#  attachments :string           default([]), is an Array
#  cc          :string
#  bcc         :string
#  raw_email   :text
#

class Post < ApplicationRecord
  # This is used to skip the callbacks when importing (ie. we don't want to send
  # emails to everyone while importing)
  attr_accessor :importing
  attr_accessor :resolved
  attr_accessor :reply_id

  # Whitelist tags and attributes that are allowed in posts
  ALLOWED_TAGS = %w[strong em a p br b img ul li]
  ALLOWED_ATTRIBUTES = %w[href src class style width height target]

  belongs_to :topic, counter_cache: true, touch: true, optional: true
  belongs_to :user, touch: true, optional: true
  has_many :votes, as: :voteable, dependent: :delete_all

  # has_attachments :screenshots, accept: [ :jpg, :png, :gif, :pdf ]
  has_many_attached :screenshots
  validate :active_storeage_valiation

  has_many :flags
  mount_uploaders :attachments, AttachmentUploader

  # validates :body, length: { maximum: 100_000 }
  # before_validation :truncate_body
  validates :kind, :user, :user_id, :body, presence: true

  after_create  :update_waiting_on_cache, unless: :importing
  after_create  :assign_on_reply, unless: :importing
  after_commit  :notify, on: :create, unless: :importing
  before_save :reject_admin_email_from_cc
  after_save  :update_topic_cache

  scope :all_by_topic, ->(topic) { where("topic_id = ?", topic).order("updated_at ASC").include(user) }
  scope :active, -> { where(active: true) }
  scope :ispublic, -> { where.not(kind: "note") }
  scope :chronologic, -> { order("created_at ASC") }
  # scope :reverse, -> { order("created_at DESC") }
  scope :by_votes, -> { order("points DESC") }
  scope :notes, -> { where(kind: "note") }

  def self.new_with_cc(topic)
    if topic.posts.size == 0
      topic.posts.new
    else
      topic.posts.new(
        cc: topic.posts.ispublic.order(id: :asc).last&.cc,
        bcc: topic.posts.ispublic.order(id: :asc).last&.bcc
      )
    end
  end

  # updates the last post date for both the forum and the topic
  # updates the waiting on cache
  def update_waiting_on_cache
    status = self.topic.current_status
    waiting_on = self.topic.waiting_on

    # unless status == 'closed' || status == 'trash'
    unless status == "trash"
      logger.info("private message, update waiting on cache")
      status = self.topic.current_status
      if self.user && self.user.is_agent?
        logger.info("waiting on user")
        waiting_on = "user"
        status = "open"
      else
        logger.info("waiting on admin")
        waiting_on = "admin"
        status = "pending" unless [ "new", "trash", "spam" ].include? self.topic.current_status
      end
    end

    self.topic.update(last_post_date: Time.current, waiting_on: waiting_on, current_status: status)
    self.topic.forum.update(last_post_date: Time.current)
  end

  # updates cache of post content used in search
  def update_topic_cache
    unless self.kind == "note"
      current_cache = self.topic.post_cache
      self.topic.update(post_cache: "#{current_cache} #{self.body}")
    end
  end

  # Assign the parent topic if not assigned and this is a reply by admin
  # or agents
  def assign_on_reply
    # don't assign if this is the first post (indicates an admin created ticket)
    return if self.topic.posts.size == 1

    if self.topic.assigned_user_id.nil?
      self.topic.assigned_user_id = self.user.is_agent? ? self.user_id : nil
    end
  end

  # send notification to agents/admins if configured
  # this logic resides in the modal because we want the same actions
  # regardless of how the post is created (web, email, api, etc)
  def notify
    # Handle new private ticket notification:
    if self.kind == "first" && self.topic.private?
      NotificationMailer.new_private(self.topic_id).deliver_later
    # Handles new public ticket notification:
    elsif self.kind == "first" && self.topic.public?
      NotificationMailer.new_public(self.topic_id).deliver_later

    # Handles customer reply notification:
    elsif self.kind == "reply" && self.user_id == self.topic.user_id && self.topic.private?
      NotificationMailer.new_reply(self.topic_id).deliver_later

    # Reply from user back to the system
    elsif self.kind == "reply" && self.user_id != self.topic.user_id && self.topic.private?
      I18n.with_locale(self.email_locale) do
        PostMailer.new_post(id).deliver_later
      end
    end
  end

  def email_locale
    return I18n.locale if self.first?
    self.topic.locale.nil? ? I18n.locale : self.topic.locale.to_sym
  end

  def importing?
    self.importing || false
  end

  def first?
    self.topic.posts.first == self
  end

  def html_formatted_body
    trimmed_body = EmailReplyTrimmer.trim(body)
    "#{ActionController::Base.helpers.sanitize(ApplicationController.helpers.body_tokens(trimmed_body, topic).gsub(/(?:\n\r?|\r\n?)/, '<br>'), tags: ALLOWED_TAGS, attributes: ALLOWED_ATTRIBUTES)}".html_safe
  end

  def text_formatted_body
    trimmed_body = EmailReplyTrimmer.trim(body)
    "#{ActionView::Base.full_sanitizer.sanitize(ApplicationController.helpers.body_tokens(trimmed_body, topic))}".html_safe
  end

  def bccs
    bccs = []
    unless bcc.nil?
      bccs += bcc&.split(",").collect { |b| b.strip }
    end
    unless AppSettings["settings.global_bcc"].nil? || AppSettings["settings.global_bcc"].blank?
      bccs += AppSettings["settings.global_bcc"]&.split(",").collect { |b| b.strip }
    end
    bccs
  end

  private

  def truncate_body
    self.body = body.truncate(10_000) unless body.blank?
  end

  def reject_admin_email_from_cc
    return if self.cc.nil?
    self.cc = self.cc.split(",").delete_if { |c| c.include?(AppSettings["email.admin_email"]) }.join(",")
  end

  def active_storeage_valiation
    return unless screenshots.attached?

    allowed_types = %w[image/jpeg image/png image/gif application/pdf]

    screenshots.each do |screenshot|
      unless screenshot.content_type.in?(allowed_types)
        screenshot.purge # Remove invalid file
        errors.add(:screenshots, "Only the following are allowed: jpeg, png, gif, pdf")
      end
    end
  end
end
