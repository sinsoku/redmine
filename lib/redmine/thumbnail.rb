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

require 'fileutils'
require 'timeout'

module Redmine
  module Thumbnail
    extend Redmine::Utils::Shell

    CONVERT_BIN = (Redmine::Configuration['imagemagick_convert_command'] || 'convert').freeze
    GS_BIN = (
      Redmine::Configuration['gs_command'] ||
      ('gswin64c' if Redmine::Platform.mswin?) ||
      'gs'
    ).freeze
    ALLOWED_TYPES = %w(image/bmp image/gif image/jpeg image/png image/webp application/pdf)

    # Generates a thumbnail for the source image to target
    # @rbs (String, String, Integer, ?bool) -> String?
    def self.generate(source, target, size, is_pdf = false)
      return nil unless convert_available?
      return nil if is_pdf && !gs_available?

      unless File.exist?(target)
        # Make sure we only invoke Imagemagick if the file type is allowed
        mime_type = File.open(source) {|f| Marcel::MimeType.for(f)}
        return nil unless ALLOWED_TYPES.include? mime_type
        return nil if is_pdf && mime_type != "application/pdf"

        directory = File.dirname(target)
        FileUtils.mkdir_p directory
        size_option = "#{size}x#{size}>"

        if is_pdf
          cmd = "#{shell_quote CONVERT_BIN} #{shell_quote "#{source}[0]"} -thumbnail #{shell_quote size_option} #{shell_quote "png:#{target}"}"
        else
          cmd = "#{shell_quote CONVERT_BIN} #{shell_quote source} -auto-orient -thumbnail #{shell_quote size_option} #{shell_quote target}"
        end

        pid = nil
        begin
          Timeout.timeout(Redmine::Configuration['thumbnails_generation_timeout'].to_i) do
            pid = Process.spawn(cmd)
            _, status = Process.wait2(pid)
            unless status.success?
              logger.error("Creating thumbnail failed (#{status.exitstatus}):\nCommand: #{cmd}")
              return nil
            end
          end
        rescue Timeout::Error
          Process.kill('KILL', pid)
          logger.error("Creating thumbnail timed out:\nCommand: #{cmd}")
          return nil
        end
      end
      target
    end

    # @rbs () -> bool
    def self.convert_available?
      return @convert_available if defined?(@convert_available)

      begin
        `#{shell_quote CONVERT_BIN} -version`
        @convert_available = $?.success?
      rescue
        @convert_available = false
      end
      logger.warn("Imagemagick's convert binary (#{CONVERT_BIN}) not available") unless @convert_available
      @convert_available
    end

    # @rbs () -> bool
    def self.gs_available?
      return @gs_available if defined?(@gs_available)

      begin
        `#{shell_quote GS_BIN} -version`
        @gs_available = $?.success?
      rescue
        @gs_available = false
      end
      logger.warn("gs binary (#{GS_BIN}) not available") unless @gs_available
      @gs_available
    end

    # @rbs () -> ActiveSupport::BroadcastLogger
    def self.logger
      Rails.logger
    end
  end
end
