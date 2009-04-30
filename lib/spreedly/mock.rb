require 'spreedly/common'

raise "Real Spreedly already required!" if defined?(Spreedly::REAL)

module Spreedly
  MOCK = "mock"
  
  def self.configure(name, token)
    @site_name = name
  end
  
  def self.site_name
    @site_name
  end
  
  class Resource
    def self.attributes
      @attributes ||= {}
    end

    def self.attributes=(value)
      @attributes = value
    end
    
    def initialize(params={})
      @attributes = params
      self.class.attributes.each{|k,v| @attributes[k] = v.call}
    end
    
    def id
      @attributes[:id]
    end

    def method_missing(method, *args)
      if method.to_s =~ /\?$/
        send(method.to_s[0..-2], *args)
      elsif @attributes.include?(method)
        @attributes[method]
      else
        super
      end
    end
  end
  
  class Subscriber < Resource
    self.attributes = {
      :created_at => proc{Time.now},
      :token => proc{(rand * 1000).round},
      :active => proc{false},
      :store_credit => proc{BigDecimal("0.0")},
      :active_until => proc{nil},
      :feature_level => proc{""},
      :on_trial => proc{false}
    }

    def self.wipe! # :nodoc: all
      @subscribers = nil
    end
    
    def self.create!(id, email=nil, screen_name=nil) # :nodoc: all
      sub = new({:id => id, :email => email, :screen_name => screen_name})

      if subscribers[sub.id]
        raise "Could not create subscriber: already exists."
      end

      subscribers[sub.id] = sub
      sub
    end
    
    def self.delete!(id)
      subscribers.delete(id)
    end
    
    def self.find(id)
      subscribers[id]
    end
    
    def self.subscribers
      @subscribers ||= {}
    end
    
    def self.all
      @subscribers.values
    end
    
    def initialize(params={})
      super
      if !id || id == ''
        raise "Could not create subscriber: no id passed OR already exists."
      end
    end
    
    def comp(quantity, units, feature_level=nil)
      raise "Could not comp subscriber: no longer exists." unless self.class.find(id)
      raise "Could not comp subscriber: validation failed." unless units && quantity
      current_active_until = (active_until || Time.now)
      @attributes[:active_until] = case units
      when 'days'
        current_active_until + (quantity.to_i * 86400)
      when 'months'
        current_active_until + (quantity.to_i * 30 * 86400)
      end
      @attributes[:feature_level] = feature_level if feature_level
      @attributes[:active] = true
    end

    def activate_free_trial(subscription_id)
      raise "Could not active free trial for subscriber: subscriber or subscription plan no longer exists." unless self.class.find(id)
      raise "Could not activate free trial for subscriber: validation failed. missing subscription plan id" unless subscription_id
      @attributes[:active] = true
      @attributes[:on_trial] = true
    end
  end
  
  class SubscriptionPlan < Resource
    def self.all
      plans.values
    end
    
    def self.find(id)
      plans[id.to_i]
    end
    
    def self.plans
      @plans ||= {1 => new(:id => 1, :name => 'Default mock plan')}
    end
  end
end