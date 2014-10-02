# encoding: utf-8
require 'json'
require 'backports/rails/hash'

class Struct
  def to_hash
    members.inject({}) {|h,m| h[m] = send(m); h}
  end unless method_defined? :to_hash

  def set(h = {})
    h.symbolize_keys!
    members.each {|m| send("#{m}=", h[m]) if h.key?(m)}
    self
  end unless method_defined? :set

  def self.from_hash(h)
    h.symbolize_keys!
    members.inject(new) {|o,m| o[m] = h[m] if h.key?(m); o}
  end unless respond_to? :from_hash

  def to_json
    to_hash.to_json
  end unless method_defined? :to_json

  def self.from_json(j)
    from_hash(JSON.parse(j))
  end unless respond_to? :from_json
end