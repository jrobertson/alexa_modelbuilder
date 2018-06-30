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
    @interact_model
  end
  
  def to_json(pretty: true)
    pretty ? JSON.pretty_generate(@interact_model) : @interact_model.to_json
  end
  
  def to_s()
    @s
  end

  private

  def parse(lines)

    puts 'inside parse' if @debug
    
    interaction = [
      [:root, 'invocation: :invocation', :invocation],
      [:root, 'types: :types', :types],
          [:types, /(.*)/, :type],
      [:root, ':intent', :intent],
        [:intent, ':utterance', :utterance],
        [:intent, /slots:/, :slots],
          [:slots, /(.*)/, :slot],
      [:all, /#/, :comment]
    ]

    a = %w(
      vendorId
      locale
      name
      summary
      description
      keywords
      examplePhrases
      testingInstructions
      endpoint
    )


    manifest = a.map do |word|
      x = word.gsub(/(?<=.)(?=[A-Z])/,'_').downcase
      [:root, "%s: :%s" % [x,x], x.to_sym]
    end
        
    a2 =  manifest + interaction
    puts 'a2: ' + a2.inspect if @debug
    lp = LineParser.new a2, debug: @debug
    lp.parse lines
    h = lp.to_h
    puts 'h: ' + h.inspect if @debug
    
    model = {
      'interactionModel' => {
        'languageModel' => {
          'invocationName' => '',
          'intents' => [],
          'types' => []
        }
      }
    }

    lm = model['interactionModel']['languageModel']
    lm['invocationName'] = h[:invocation]

    intents = h[:intent].map do |row|

      name, value = row.is_a?(Hash) ? row.to_a.first : [row, {}]
      intent = {'name' => name  , 'samples' => value[:utterance] || [] }

      slots = value[:slots]

      if slots then

        a = slots.is_a?(Array) ? value[:slots] : [slots]

        intent['slots'] = a.map do |slot|

          name, type = slot.split(/: */,2)
          {'name' => name, 'type' => type, 'samples' => []}

        end    

      end

      intent

    end

    lm['intents'] = intents

    if h[:types] then

      (h[:types].is_a?(Array) ? h[:types] : [h[:types]]).map do |raw_type|

          name, raw_val = raw_type.split(/: */)
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

    end

    @interact_model = model

  end

end
