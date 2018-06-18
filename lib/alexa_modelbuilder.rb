#!/usr/bin/env ruby

# file: alexa_modelbuilder.rb


require 'json'
require 'lineparser'


class AlexaModelBuilder

  attr_reader :to_h, to_json

  def initialize(s)

    parse(s)

  end

  private

  def parse(lines)

    patterns = [
      [:root, 'invocation: :invocation', :invocation],
      [:root, 'types: :types', :types],
          [:types, /(.*)/, :type],
      [:root, ':intent', :intent],
        [:intent, ':utterance', :utterance],
        [:intent, 'slots: :slots', :slots],
          [:slots, /(.*)/, :slot],
      [:all, /#/, :comment]
    ]

    lp = LineParser.new patterns
    r = lp.parse lines

    h = {
      'interactionModel' => {
        'languageModel' => {
          'invocationName' => '',
          'intents' => [],
          'types' => []
        }
      }
    }

    lm = h['interactionModel']['languageModel']
    lm['invocationName'] = r[0][1].values.first

    raw_intents = r.select {|x| x.first == :intent}

    intents = raw_intents.map do |x|

      {'name' => x[1].values.first, 'samples' => [] }

    end

    lm['intents'] = intents

    raw_types = r.find {|x| x.first == :types}

    if raw_types then

      name, raw_val = raw_types[2][1].first.split(/: */)
      values = raw_val.split(/, */)

      types = {'name' => name, 'values' => values.map {|x| {'name' => {'value' => x }} } }

      lm['types'] = types

    end

    @to_h = h
    @to_json = h.to_json

  end

end

