#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: John Keiser (<jkeiser@opscode.com>)
# Copyright:: Copyright (c) 2012 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/config'
require 'uri'
# These are needed so that JSON can inflate search results
require 'chef/node'
require 'chef/role'
require 'chef/environment'
require 'chef/data_bag'
require 'chef/data_bag_item'

class PartialSearch

  attr_accessor :rest

  def initialize(url=nil)
    @rest = ::Chef::ServerAPI.new(url || ::Chef::Config[:chef_server_url])
  end

  # Search Solr for objects of a given type, for a given query. If you give
  # it a block, it will handle the paging for you dynamically.
  def search(type, query='*:*', args={}, &block)
    raise ArgumentError, "Type must be a string or a symbol!" unless (type.kind_of?(String) || type.kind_of?(Symbol))

    sort = args.include?(:sort) ? args[:sort] : 'X_CHEF_id_CHEF_X asc'
    start = args.include?(:start) ? args[:start] : 0
    rows = args.include?(:rows) ? args[:rows] : 1000
    query_string = "search/#{type}?q=#{escape(query)}&sort=#{escape(sort)}&start=#{escape(start)}&rows=#{escape(rows)}"
    if args[:keys]
      response = @rest.post_rest(query_string, args[:keys])
      response_rows = response['rows'].map { |row| row['data'] }
    else
      response = @rest.get_rest(query_string)
      response_rows = response['rows']
    end
    if block
      response_rows.each { |o| block.call(o) unless o.nil?}
      unless (response["start"] + response_rows.length) >= response["total"]
        nstart = response["start"] + rows
        args_hash = {
          :keys => args[:keys],
          :sort => sort,
          :start => nstart,
          :rows => rows
        }
        search(type, query, args_hash, &block)
      end
      true
    else
      [ response_rows, response["start"], response["total"] ]
    end
  end

  def list_indexes
    response = @rest.get_rest("search")
  end

  private
    def escape(s)
      s && URI.escape(s.to_s)
    end
end
