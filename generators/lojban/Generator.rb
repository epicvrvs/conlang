require 'set'

require 'nil/random'

require 'application/Array'

module Generator
  Vowels = [
    'a',
    'i',
    'u',
    'e',
    'o',
    '@',
  ]

  Nasals = [
    'm',
    'n',
    #'J',
  ]

  VoicelessPlosives = [
    'k',
    'p',
    't',
  ]

  VoicedPlosives = [
    'g',
    'b',
    'd',
  ]

  Approximants = [
    #'j',
    #'w',
    'l',
    #'L',
    #'r\\`',
  ]


  VoicelessFricatives = [
    'h',
    'f',
    's',
    'S',
    #'x',
    #'X',
    #'C',
    #'T',
  ]

  VoicedFricatives = [
    'v',
    'z',
    'Z',
    #'G',
    #'R',
    #'j\\',
    #'D',
  ]

  Taps = [
    '4',
  ]

  Stops = [
    '?',
  ]

  VoicelessAffricates = [
    'tS',
    'ts',
  ]

  VoicedAffricates = [
    'dZ',
    'dz',
  ]

  Plosives = VoicelessPlosives + VoicedPlosives
  Fricatives = VoicelessFricatives + VoicedFricatives
  Affricates = VoicelessAffricates + VoicedAffricates

  InitialClusters =
    Affricates +
    ['s', 'S'] * VoicelessPlosives +
    ['k', 'p', 'g', 'b'] * ['l']

  MedialClusters =
    ['m'] * ['p', 'b'] +
    ['l'] * Plosives

  Consonants = Nasals + Plosives + Approximants + Fricatives + Taps + Stops

  BasicSyllables = Consonants * Vowels

  Words = [
    BasicSyllables,
    InitialClusters * Vowels * BasicSyllables + BasicSyllables * MedialClusters * Vowels,
  ].map { |x| x.to_set }

  SyllableCounts = [
    1,
    2,
  ]

  def self.totalWordCount
    count = 0
    Words.each do |wordClass|
      count += wordClass.size
    end
    return count
  end

  def self.printClassSizes
    puts "Class sizes:"
    Generator::Words.each do |words|
      puts words.size
    end
  end

  def self.printWordCount
    puts "Total word count: #{Generator.totalWordCount}"
  end

  def self.generateWord(priority)
    while true
      words = Words[priority].to_a
      word = words[rand(words.size)]
      return word
    end
  end

  def self.describe
    puts "Vowels: #{Vowels.size}"
    puts "Consonants: #{Consonants.size}"
    self.printClassSizes
    self.printWordCount
  end

  def self.noise(syllableCount)
    generatedWords = []
    scale = Nil::RandomScale.new
    weights = [2, 1]
    Words.size.times do |i|
      scale.add(i, weights[i])
    end
    while syllableCount > 0
      priority = scale.get
      currentSyllableCount = SyllableCounts[priority]
      if currentSyllableCount > syllableCount
        next
      end
      syllableCount -= currentSyllableCount
      generatedWords << self.generateWord(priority)
    end
    return generatedWords.join(' ')
  end

  def self.getPriority(word)
    priority = 0
    Words.each do |wordClass|
      if wordClass.include?(word)
        return priority
      end
      priority += 1
    end
    return nil
  end

  def self.generateUnusedWord(usedWords, priority)
    unusedWords = Generator::Words[priority].reject do |word|
      usedWords.include?(word)
    end
    if unusedWords.empty?
      return nil
    end
    word = unusedWords[rand(unusedWords.size)]
    return word
  end
end
