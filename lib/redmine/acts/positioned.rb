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

module Redmine
  module Acts
    module Positioned
      def self.included(base)
        base.extend ClassMethods
      end

      # This extension provides the capabilities for reordering objects in a list.
      # The class needs to have a +position+ column defined as an integer on the
      # mapped database table.
      module ClassMethods
        # Configuration options are:
        #
        # * +scope+ - restricts what is to be considered a list. Must be a symbol
        # or an array of symbols
        # @rbs (?Hash[untyped, untyped]) -> void
        def acts_as_positioned(options = {})
          class_attribute :positioned_options
          self.positioned_options = {:scope => Array(options[:scope])}

          send :include, Redmine::Acts::Positioned::InstanceMethods

          before_save :set_default_position
          after_save :update_position
          after_destroy :remove_position
        end
      end

      module InstanceMethods
        # @rbs (Class) -> Class
        def self.included(base)
          base.extend ClassMethods
        end

        private

        # @rbs () -> (GroupCustomField::ActiveRecord_Relation | IssueCustomField::ActiveRecord_Relation | TimeEntryCustomField::ActiveRecord_Relation | TimeEntryActivity::ActiveRecord_Relation | ProjectCustomField::ActiveRecord_Relation | Board::ActiveRecord_Relation | CustomField::ActiveRecord_Relation | Role::ActiveRecord_Relation | Tracker::ActiveRecord_Relation | IssueStatus::ActiveRecord_Relation | IssuePriority::ActiveRecord_Relation | DocumentCategory::ActiveRecord_Relation | Enumeration::ActiveRecord_Relation | VersionCustomField::ActiveRecord_Relation | UserCustomField::ActiveRecord_Relation | TimeEntryActivityCustomField::ActiveRecord_Relation | IssuePriorityCustomField::ActiveRecord_Relation)
        def position_scope
          build_position_scope {|c| send(c)}
        end

        # @rbs () -> (Board::ActiveRecord_Relation | ProjectCustomField::ActiveRecord_Relation | IssueCustomField::ActiveRecord_Relation | UserCustomField::ActiveRecord_Relation | TimeEntryActivityCustomField::ActiveRecord_Relation | TimeEntryCustomField::ActiveRecord_Relation | CustomField::ActiveRecord_Relation | IssuePriority::ActiveRecord_Relation | Tracker::ActiveRecord_Relation | IssueStatus::ActiveRecord_Relation | Role::ActiveRecord_Relation | TimeEntryActivity::ActiveRecord_Relation)
        def position_scope_was
          # this can be called in after_update or after_destroy callbacks
          # with different methods in Rails 5 for retrieving the previous value
          build_position_scope {|c| send(destroyed? ? "#{c}_was" : "#{c}_before_last_save")}
        end

        # @rbs () -> (GroupCustomField::ActiveRecord_Relation | Board::ActiveRecord_Relation | IssueCustomField::ActiveRecord_Relation | TimeEntryCustomField::ActiveRecord_Relation | TimeEntryActivity::ActiveRecord_Relation | ProjectCustomField::ActiveRecord_Relation | UserCustomField::ActiveRecord_Relation | TimeEntryActivityCustomField::ActiveRecord_Relation | CustomField::ActiveRecord_Relation | Role::ActiveRecord_Relation | Tracker::ActiveRecord_Relation | IssueStatus::ActiveRecord_Relation | IssuePriority::ActiveRecord_Relation | DocumentCategory::ActiveRecord_Relation | Enumeration::ActiveRecord_Relation | VersionCustomField::ActiveRecord_Relation | IssuePriorityCustomField::ActiveRecord_Relation)
        def build_position_scope
          condition_hash = self.class.positioned_options[:scope].inject({}) do |h, column|
            h[column] = yield(column)
            h
          end
          self.class.unscoped.where(condition_hash)
        end

        # @rbs () -> Integer?
        def set_default_position
          if position.nil?
            self.position = position_scope.maximum(:position).to_i + (new_record? ? 1 : 0)
          end
        end

        # @rbs () -> Integer?
        def update_position
          if !new_record? && position_scope_changed?
            remove_position
            insert_position
          elsif saved_change_to_position?
            if position_before_last_save.nil?
              insert_position
            else
              shift_positions
            end
          end
        end

        # @rbs () -> Integer
        def insert_position
          position_scope.where("position >= ? AND id <> ?", position, id).update_all("position = position + 1")
        end

        # @rbs () -> Integer
        def remove_position
          # this can be called in after_update or after_destroy callbacks
          # with different methods in Rails 5 for retrieving the previous value
          previous = destroyed? ? position_was : position_before_last_save
          position_scope_was.where("position >= ? AND id <> ?", previous, id).update_all("position = position - 1")
        end

        # @rbs () -> bool
        def position_scope_changed?
          saved_changes.keys.intersect?(self.class.positioned_options[:scope].map(&:to_s))
        end

        # @rbs () -> nil
        def shift_positions
          offset = position_before_last_save <=> position
          min, max = [position, position_before_last_save].sort
          r = position_scope.where("id <> ? AND position BETWEEN ? AND ?", id, min, max).update_all("position = position + #{offset}")
          if r != max - min
            reset_positions_in_list
          end
        end

        def reset_positions_in_list
          position_scope.reorder(:position, :id).pluck(:id).each_with_index do |record_id, p|
            self.class.where(:id => record_id).update_all(:position => p+1)
          end
        end
      end
    end
  end
end
