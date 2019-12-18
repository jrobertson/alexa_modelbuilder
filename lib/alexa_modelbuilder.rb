#!/usr/bin/env ruby

# file: alexa_modelbuilder.rb


require 'json'
require 'clipboard'
require 'lineparser'



class AlexaModelBuilder
  using ColouredText
  
  attr_reader :name, :invocation, :utterances

  def initialize(s=nil, debug: false, locale: 'en-GB')

    @debug, @locale = debug, locale
    parse(s) if s

  end
  
  # fetch the intents from the document model
  #
  def intents()
    self.to_h[:intent].map {|x| x.keys.first}
  end
  
  # Read an Alexa Interaction Model (in JSON format)
  #
  def read(obj)
    
    s, _ = RXFHelper.read(obj)
    
    h = JSON.parse(s, symbolize_names: true)
    
    lm = h[:interactionModel][:languageModel]
    lm[:invocationName]

    out = []
    out << 'invocation: ' + lm[:invocationName] + "\n"
    puts lm[:intents].inspect if @debug
    
    lm[:intents].each do |intent|

      puts ('intent: ' + intent[:name].inspect).debug if @debug
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
  
  # Returns a generated manifest from the document model
  #
  def to_manifest(json: false)
    json ? JSON.pretty_generate(@manifest) : @manifest
  end
  
  
  # Builds an Alexa manifest from a hash object containing the values 
  # parsed from the document model
  #
  # A guideline of fields to include within the raw document
  
=begin
manifest

vendorId: [generate from vendors.first]
locale: input (default)
name: input
summary: input (default)
description: input (default)
keywords: input (default)
examplePhrases: [generate from intent utterances]
testingInstructions: input [generate from intent utterances]
endpoint: input    
=end
  #
  def build_manifest(h)    
    
    manifest = {
        "manifest" => {
            "publishingInformation" => {
                "locales" => {
                },
                "isAvailableWorldwide" => false,
                "testingInstructions" => "1) Say 'Alexa, say something'",
                "category" => "SMART_HOME",
                "distributionCountries" => [
                ]
            },
            "apis" => {
                "custom" => {
                    "endpoint" => {
                        "sslCertificateType"=>"Trusted",
                        "uri" => "https://someserver.com/alexaskills"
                    }
                }
            },
            "manifestVersion" => "1.0",
            "privacyAndCompliance" => {
                "allowsPurchases" => false,
                "locales" => {
                },
                "isExportCompliant" => true,
                "isChildDirected" => false,
                "usesPersonalInfo" => false
            }
        }
    }    

    manifest['vendorId'] = h[:vendor_id] if h[:vendor_id]
    m = manifest['manifest']
    
    h[:locale] ||= @locale
    
    
    info = {}
    info['summary'] = h[:summary] || h[:name]
    
    @utterances = h[:intent].select{|x| x.is_a? Hash}.flat_map do |x|
      x.first[-1][:utterance]
    end
    
    examples = ["Alexa, open %s." % h[:invocation]]
    examples += h[:intent].select{|x| x.is_a? Hash}.take(2).map do |x|
      phrases = x.first[-1][:utterance]
      puts 'phrases: ' + phrases.inspect if @debug
      "Alexa, %s." % (phrases.is_a?(Array) ? phrases.first : phrases)
    end
    
    info['examplePhrases'] = examples
    info['keywords'] = h[:keywords] ? h[:keywords] : \
        h[:name].split.map(&:downcase)

    info['name'] = h[:name] if h[:name]
    info['description'] = h[:description] || info['summary']
    
    m['publishingInformation']['locales'] = {h[:locale] => info}
    countries = {gb: %w(GB US), us: %w(US GB)}
    m['publishingInformation']['distributionCountries'] = \
        countries[h[:locale][/[A-Z]+/].downcase.to_sym]
    m['apis']['custom']['endpoint']['uri'] = h[:endpoint] if h[:endpoint]
    
    toc = {
      'termsOfUseUrl' => 'http://www.termsofuse.sampleskill.com',
      'privacyPolicyUrl' => 'http://www.myprivacypolicy.sampleskill.com'
    }
    m['privacyAndCompliance']['locales'] = {h[:locale] => toc}

    
    instruct = ["open %s" % h[:invocation]]
    instruct << h[:intent].select{|x| x.is_a? Hash}\
        .first.values.first[:utterance].first

    tests = instruct.map.with_index {|x, i| "%s) Say 'Alexa, %s'" % [i+1, x]}
    m['publishingInformation']['testingInstructions'] = tests.join(' ')
    
    manifest
  end


  # Returns an Alexa Interaction model as a Hash object
  #
  def to_model(json: false)
    json ? JSON.pretty_generate(@interact_model) : @interact_model
  end
  
  # Returns an Alexa Interaction Model in JSON format
  def to_json(pretty: true, copy: false)
    
    json = pretty ? JSON.pretty_generate(@interact_model) : \
        @interact_model.to_json
    
    Clipboard.copy json if copy
    return json
  end
  
  def to_s()
    @s
  end

  private

  # Parses the document model using the line-parser gem
  #
  def parse(raw_s)
    
    s, _ = RXFHelper.read(raw_s)

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
    lp.parse s
    @h = h = lp.to_h
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
    @name = h[:name]
    lm['invocationName'] = @invocation = h[:invocation]

    intents = h[:intent].map do |row|

      name, value = row.is_a?(Hash) ? row.to_a.first : [row, {}]
      
      value[:utterance] ||= []
      samples = value[:utterance].is_a?(Array) ? value[:utterance] : \
          [value[:utterance]]
      intent = {'name' => name  , 'samples' => samples}

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

    @manifest = build_manifest h
    @interact_model = model

  end

end
