#!/usr/bin/env ruby

# file: alexa_modelbuilder.rb


require 'json'
require 'lineparser'


class AlexaModelBuilder

  def initialize(s)

    parse(s)

  end
  
  def to_h()
    @h
  end
  
  def to_json(pretty: true)
    pretty ? JSON.pretty_generate(@h) : @h.to_json
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

      raw_utterances = x[3].select {|y| y.first == :utterance}

      utterances = raw_utterances.map {|z| z[2].first.rstrip }

      intent = {'name' => x[1].values.first, 'samples' => utterances }
      raw_slots = x[3].find {|x| x.first == :slots }

      if raw_slots then
        
        intent['slots'] = raw_slots[3].map do |slot|

          name, type = slot[2].first.split(/: */,2)
          {'name' => name, 'type' => type, 'samples' => []}

        end
      end

      intent

    end


    lm['intents'] = intents

    raw_types = r.find {|x| x.first == :types}

    if raw_types then

      name, raw_val = raw_types[2][1].first.split(/: */)
      values = raw_val.split(/, */)

      types = {'name' => name, 'values' => []}
      types['values'] = values.map {|x|{'name' => {'value' => x }} }

      lm['types'] = types

    end

    @h = h

  end

end
