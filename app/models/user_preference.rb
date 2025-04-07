# frozen_string_literal: true

# Redmine - project management software
# Copyright (C) 2006-  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require 'redmine/my_page'

class UserPreference < ApplicationRecord
  include Redmine::SafeAttributes

  belongs_to :user
  serialize :others

  before_save :set_others_hash, :clear_unused_block_settings

  safe_attributes(
    'hide_mail',
    'time_zone',
    'comments_sorting',
    'warn_on_leaving_unsaved',
    'no_self_notified',
    'notify_about_high_priority_issues',
    'textarea_font',
    'recently_used_projects',
    'history_default_tab',
    'default_issue_query',
    'default_project_query',
    'toolbar_language_options',
    'auto_watch_on')

  TEXTAREA_FONT_OPTIONS = ['monospace', 'proportional']
  DEFAULT_TOOLBAR_LANGUAGE_OPTIONS = %w[c cpp csharp css diff go groovy html java javascript objc perl php python r ruby sass scala shell sql swift xml yaml]
  AUTO_WATCH_ON_OPTIONS = %w[issue_created issue_contributed_to]

  # @rbs (?Hash[untyped, untyped]?, *nil) -> void
  def initialize(attributes=nil, *args)
    super
    if new_record?
      unless attributes && attributes.key?(:hide_mail)
        self.hide_mail = Setting.default_users_hide_mail?
      end
      unless attributes && attributes.key?(:time_zone)
        self.time_zone = Setting.default_users_time_zone
      end
      unless attributes && attributes.key?(:no_self_notified)
        self.no_self_notified = Setting.default_users_no_self_notified
      end
      unless attributes && attributes.key?(:auto_watch_on)
        self.auto_watch_on = AUTO_WATCH_ON_OPTIONS
      end
    end
    self.others ||= {}
  end

  # @rbs () -> Hash[untyped, untyped]
  def set_others_hash
    self.others ||= {}
  end

  # @rbs (Symbol | String) -> (String | bool | Hash[untyped, untyped] | Integer | Array[untyped])?
  def [](attr_name)
    if has_attribute? attr_name
      super
    else
      others ? others[attr_name] : nil
    end
  end

  # @rbs (String | Symbol, (Integer | String | Array[untyped] | Hash[untyped, untyped] | bool)?) -> (Integer | String | Array[untyped] | Hash[untyped, untyped] | bool)?
  def []=(attr_name, value)
    if has_attribute? attr_name
      super
    else
      h = (read_attribute(:others) || {}).dup
      h.update(attr_name => value)
      write_attribute(:others, h)
      value
    end
  end

  # @rbs () -> String?
  def comments_sorting; self[:comments_sorting]; end
  # @rbs (String) -> String
  def comments_sorting=(order); self[:comments_sorting]=order; end

  # @rbs () -> String
  def warn_on_leaving_unsaved; self[:warn_on_leaving_unsaved] || '1'; end
  # @rbs (String) -> String
  def warn_on_leaving_unsaved=(value); self[:warn_on_leaving_unsaved]=value; end

  # @rbs () -> bool
  def no_self_notified; (self[:no_self_notified] == true || self[:no_self_notified] == '1'); end
  # @rbs (String | bool) -> (String | bool)
  def no_self_notified=(value); self[:no_self_notified]=value; end

  # @rbs () -> bool
  def notify_about_high_priority_issues; (self[:notify_about_high_priority_issues] == true || self[:notify_about_high_priority_issues] == '1'); end
  # @rbs (String | bool) -> (String | bool)
  def notify_about_high_priority_issues=(value); self[:notify_about_high_priority_issues]=value; end

  # @rbs () -> Array[untyped]
  def activity_scope; Array(self[:activity_scope]); end
  # @rbs (Array[untyped]) -> void
  def activity_scope=(value); self[:activity_scope]=value; end

  # @rbs () -> String?
  def textarea_font; self[:textarea_font]; end
  # @rbs (String) -> String
  def textarea_font=(value); self[:textarea_font]=value; end

  # @rbs () -> Integer
  def recently_used_projects; (self[:recently_used_projects] || 3).to_i; end
  # @rbs (Integer) -> void
  def recently_used_projects=(value); self[:recently_used_projects] = value.to_i; end
  # @rbs () -> nil
  def history_default_tab; self[:history_default_tab]; end
  # @rbs (String) -> String
  def history_default_tab=(value); self[:history_default_tab]=value; end

  # @rbs () -> String
  def toolbar_language_options
    self[:toolbar_language_options].presence || DEFAULT_TOOLBAR_LANGUAGE_OPTIONS.join(',')
  end

  # @rbs (String) -> void
  def toolbar_language_options=(value)
    languages =
      value.to_s.delete(' ').split(',').select do |lang|
        Redmine::SyntaxHighlighting.language_supported?(lang)
      end.compact
    self[:toolbar_language_options] = languages.join(',')
  end

  # @rbs () -> Integer?
  def default_issue_query; self[:default_issue_query] end
  # @rbs (Integer) -> Integer
  def default_issue_query=(value); self[:default_issue_query]=value; end

  # @rbs () -> Integer?
  def default_project_query; self[:default_project_query] end
  # @rbs (Integer) -> Integer
  def default_project_query=(value); self[:default_project_query]=value; end

  # @rbs () -> Array[untyped]
  def auto_watch_on; self[:auto_watch_on] || []; end
  # @rbs (Array[untyped]) -> Array[untyped]
  def auto_watch_on=(values); self[:auto_watch_on]=values; end
  # @rbs (String) -> bool
  def auto_watch_on?(action); self.auto_watch_on.include?(action.to_s); end

  # Returns the names of groups that are displayed on user's page
  # Example:
  #   preferences.my_page_groups
  #   # => ['top', 'left, 'right']
  # @rbs () -> Array[untyped]
  def my_page_groups
    Redmine::MyPage.groups
  end

  # @rbs () -> Hash[untyped, untyped]
  def my_page_layout
    self[:my_page_layout] ||= Redmine::MyPage.default_layout.deep_dup
  end

  # @rbs (Hash[untyped, untyped]) -> void
  def my_page_layout=(arg)
    self[:my_page_layout] = arg
  end

  # @rbs (?String?) -> Hash[untyped, untyped]
  def my_page_settings(block=nil)
    s = self[:my_page_settings] ||= {}
    if block
      s[block] ||= {}
    else
      s
    end
  end

  # @rbs (Hash[untyped, untyped]?) -> void
  def my_page_settings=(arg)
    self[:my_page_settings] = arg
  end

  # Removes block from the user page layout
  # Example:
  #   preferences.remove_block('news')
  # @rbs (String) -> Hash[untyped, untyped]
  def remove_block(block)
    block = block.to_s.underscore
    my_page_layout.each_key do |group|
      my_page_layout[group].delete(block)
    end
    my_page_layout
  end

  # Adds block to the user page layout
  # Returns nil if block is not valid or if it's already
  # present in the user page layout
  # @rbs (String) -> Array[untyped]?
  def add_block(block)
    block = block.to_s.underscore
    return unless Redmine::MyPage.valid_block?(block, my_page_layout.values.flatten)

    remove_block(block)
    # add it to the first group
    group = my_page_groups.first
    my_page_layout[group] ||= []
    my_page_layout[group].unshift(block)
  end

  # Sets the block order for the given group.
  # Example:
  #   preferences.order_blocks('left', ['issueswatched', 'news'])
  # @rbs (String, Array[untyped]) -> void
  def order_blocks(group, blocks)
    group = group.to_s
    if Redmine::MyPage.groups.include?(group) && blocks.present?
      blocks = blocks.map(&:underscore) & my_page_layout.values.flatten
      blocks.each {|block| remove_block(block)}
      my_page_layout[group] = blocks
    end
  end

  # @rbs (String, ActiveSupport::HashWithIndifferentAccess) -> Hash[untyped, untyped]
  def update_block_settings(block, settings)
    block = block.to_s
    block_settings = my_page_settings(block).merge(settings.symbolize_keys)
    my_page_settings[block] = block_settings
  end

  # @rbs () -> Hash[untyped, untyped]
  def clear_unused_block_settings
    blocks = my_page_layout.values.flatten
    my_page_settings.keep_if {|block, settings| blocks.include?(block)}
  end
  private :clear_unused_block_settings
end
