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
  module Themes
    # Return an array of installed themes
    # @rbs () -> Array[untyped]
    def self.themes
      @@installed_themes ||= scan_themes
    end

    # Rescan themes directory
    # @rbs () -> Array[untyped]
    def self.rescan
      @@installed_themes = scan_themes
    end

    # Return theme for given id, or nil if it's not found
    # @rbs (String, ?Hash[untyped, untyped]) -> Redmine::Themes::Theme?
    def self.theme(id, options={})
      return nil if id.blank?

      found = themes.find {|t| t.id == id}
      if found.nil? && options[:rescan] != false
        rescan
        found = theme(id, :rescan => false)
      end
      found
    end

    # Class used to represent a theme
    class Theme
      attr_reader :path, :name, :dir

      # @rbs (String | Pathname) -> void
      def initialize(path)
        @path = path
        @dir = File.basename(path)
        @name = @dir.humanize
        @stylesheets = nil
        @javascripts = nil
      end

      # Directory name used as the theme id
      # @rbs () -> String
      def id; dir end

      # @rbs (Redmine::Themes::Theme) -> bool
      def ==(theme)
        theme.is_a?(Theme) && theme.dir == dir
      end

      # @rbs (Redmine::Themes::Theme) -> Integer
      def <=>(theme)
        return nil unless theme.is_a?(Theme)

        name <=> theme.name
      end

      # @rbs () -> Array[untyped]
      def stylesheets
        @stylesheets ||= assets("stylesheets", "css")
      end

      # @rbs () -> Array[untyped]
      def images
        @images ||= assets("images")
      end

      # @rbs () -> Array[untyped]
      def javascripts
        @javascripts ||= assets("javascripts", "js")
      end

      # @rbs () -> Array[untyped]
      def favicons
        @favicons ||= assets("favicon")
      end

      # @rbs () -> String?
      def favicon
        favicons.first
      end

      # @rbs () -> bool
      def favicon?
        favicon.present?
      end

      # @rbs (String) -> String
      def stylesheet_path(source)
        "#{asset_prefix}#{source}"
      end

      # @rbs (String) -> String
      def image_path(source)
        "#{asset_prefix}#{source}"
      end

      # @rbs (String) -> String
      def javascript_path(source)
        "#{asset_prefix}#{source}"
      end

      # @rbs () -> String
      def favicon_path
        "#{asset_prefix}#{favicon}"
      end

      # @rbs () -> String
      def asset_prefix
        "themes/#{dir}/"
      end

      # @rbs () -> Redmine::AssetPath
      def asset_paths
        base_dir = Pathname.new(path)
        paths = base_dir.children.select do |child|
          child.directory? &&
            child.basename.to_s != 'src' &&
            !child.basename.to_s.start_with?('.')
        end
        Redmine::AssetPath.new(base_dir, paths, asset_prefix)
      end

      private

      # @rbs (String, ?String?) -> Array[untyped]
      def assets(dir, ext=nil)
        if ext
          Dir.glob("#{path}/#{dir}/*.#{ext}").collect {|f| File.basename(f, ".#{ext}")}
        else
          Dir.glob("#{path}/#{dir}/*").collect {|f| File.basename(f)}
        end
      end
    end

    module Helper
      # @rbs () -> Redmine::Themes::Theme?
      def current_theme
        unless instance_variable_defined?(:@current_theme)
          @current_theme = Redmine::Themes.theme(Setting.ui_theme)
        end
        @current_theme
      end

      # Returns the header tags for the current theme
      # @rbs () -> ActiveSupport::SafeBuffer?
      def heads_for_theme
        if current_theme && current_theme.javascripts.include?('theme')
          javascript_include_tag current_theme.javascript_path('theme')
        end
      end
    end

    # @rbs () -> Array[untyped]
    def self.scan_themes
      dirs = Dir.glob(["#{Rails.root}/app/assets/themes/*", "#{Rails.root}/themes/*"]).select do |f|
        # A theme should at least override application.css
        File.directory?(f) && File.exist?("#{f}/stylesheets/application.css")
      end
      dirs.collect {|dir| Theme.new(dir)}.sort
    end
    private_class_method :scan_themes
  end
end
