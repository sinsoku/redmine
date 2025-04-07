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
  module AccessControl
    class << self
      def map
        mapper = Mapper.new
        yield mapper
        @permissions ||= []
        @permissions += mapper.mapped_permissions
      end

      # @rbs () -> Array[untyped]
      def permissions
        @permissions
      end

      # Returns the permission of given name or nil if it wasn't found
      # Argument should be a symbol
      # @rbs (Symbol) -> Redmine::AccessControl::Permission?
      def permission(name)
        permissions.detect {|p| p.name == name}
      end

      # Returns the actions that are allowed by the permission of given name
      # @rbs (Symbol) -> Array[untyped]
      def allowed_actions(permission_name)
        perm = permission(permission_name)
        perm ? perm.actions : []
      end

      # @rbs () -> Array[untyped]
      def public_permissions
        @public_permissions ||= @permissions.select {|p| p.public?}
      end

      # @rbs () -> Array[untyped]
      def members_only_permissions
        @members_only_permissions ||= @permissions.select {|p| p.require_member?}
      end

      # @rbs () -> Array[untyped]
      def loggedin_only_permissions
        @loggedin_only_permissions ||= @permissions.select {|p| p.require_loggedin?}
      end

      # @rbs (Hash[untyped, untyped] | Symbol) -> bool
      def read_action?(action)
        if action.is_a?(Symbol)
          perm = permission(action)
          !perm.nil? && perm.read?
        elsif action.is_a?(Hash)
          s = "#{action[:controller]}/#{action[:action]}"
          permissions.detect {|p| p.actions.include?(s) && p.read?}.present?
        else
          raise ArgumentError.new("Symbol or a Hash expected, #{action.class.name} given: #{action}")
        end
      end

      # @rbs () -> Array[untyped]
      def available_project_modules
        @available_project_modules ||= @permissions.collect(&:project_module).uniq.compact
      end

      # @rbs (Array[untyped]) -> Array[untyped]
      def modules_permissions(modules)
        @permissions.select {|p| p.project_module.nil? || modules.include?(p.project_module.to_s)}
      end
    end

    class Mapper
      def initialize
        @project_module = nil
      end

      def permission(name, hash, options={})
        @permissions ||= []
        @permissions.reject! {|p| p.name == name}
        options[:project_module] = @project_module
        @permissions << Permission.new(name, hash, options)
      end

      def project_module(name, options={})
        @project_module = name
        yield self
        @project_module = nil
      end

      def mapped_permissions
        @permissions
      end
    end

    class Permission
      attr_reader :name, :actions, :project_module

      def initialize(name, hash, options)
        @name = name
        @actions = []
        @public = options[:public] || false
        @require = options[:require]
        @read = options[:read] || false
        @project_module = options[:project_module]
        hash.each do |controller, actions|
          if actions.is_a? Array
            @actions << actions.collect {|action| "#{controller}/#{action}"}
          else
            @actions << "#{controller}/#{actions}"
          end
        end
        @actions.flatten!
      end

      # @rbs () -> bool
      def public?
        @public
      end

      # @rbs () -> bool?
      def require_member?
        @require && @require == :member
      end

      # @rbs () -> bool?
      def require_loggedin?
        @require && (@require == :member || @require == :loggedin)
      end

      # @rbs () -> bool
      def read?
        @read
      end
    end
  end
end
