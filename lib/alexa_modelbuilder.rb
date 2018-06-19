#!/usr/bin/env ruby

# file: alexa_modelbuilder.rb


require 'json'
require 'lineparser'


class AlexaModelBuilder

  def initialize(s=nil, debug: false)

    @debug = debug
    parse(s) if s

  end
  
  def read(s)
    
    h = JSON.parse(s, symbolize_names: true)
    
    lm = h[:interactionModel][:languageModel]
    lm[:invocationName]

    out = []
    out << 'invocation: ' + lm[:invocationName] + "\n"
    puts lm[:intents].inspect if @debug
    
    lm[:intents].each do |intent|

      puts 'intent: ' + intent[:name].inspect if @debug
      out << intent[:name] + "\n"
      
      if intent[:samples] then
        
        intent[:samples].each do |utterance|
          puts 'utterance: ' + utterance.inspect if @debug
          out << "  " + utterance
        end

        if intent[:slots] and intent[:slots].any? then

          out << "\n  slots:"

          intent[:slots].each do |slot|
            out << "    %s: %s" % [slot[:name], slot[:type]]
          end

        end

        out << "\n" if intent[:samples].any?
      end

    end

    if lm[:types] and lm[:types].any? then

      out << "types:"

      lm[:types].each do |type|
        
        values = type[:values].map do |x| 
          
          synonyms = x[:name][:synonyms]
          val = x[:name][:value]
          val += ' (' + synonyms.join(', ') + ')' if synonyms and synonyms.any?
          val
        end
        
        out << "  %s: %s" % [type[:name], values.join(', ')]
      end

    end
    out << "\n"

    @s = out.join("\n")
    #parse(@s)
    self
  end
  
  def to_h()
    @h
  end
  
  def to_json(pretty: true)
    pretty ? JSON.pretty_generate(@h) : @h.to_json
  end
  
  def to_s()
    @s
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
      
      types['values'] = values.map do |raw_val|
        
        name, raw_synonyms = raw_val.split(/ *\(/,2)
                
        h2 = {'name' => {'value' => name }}
        
        if raw_synonyms then
          synonyms = raw_synonyms[0..-2].split(/, */)
          h2['synonyms'] = synonyms
        end
        
        h2
      end

      lm['types'] = types

    end

    @h = h

  end

end
