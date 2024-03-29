require 'logger'
require 'singleton'
require 'ostruct'

module Vigilion
  class Configuration < OpenStruct
    include Singleton

    def self.configure
      yield instance
    end

    def self.method_missing(m, *args, &block)
      instance.send(m, *args)
    end
  end

  Configuration.server_url = "https://api.vigilion.com"
  Configuration.logger = Logger.new($stdout)
  Configuration.debug = false
  Configuration.do_not_unencode = false
end
