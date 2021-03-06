require 'nil/string'

require 'www-library/HTTPReply'
require 'www-library/RequestHandler'

require 'application/BaseHandler'
require 'application/Generator'
require 'application/TranslationForm'
require 'application/Translator'
require 'application/WordForm'
require 'application/WordFormContents'

require 'visual/LanguageHandler'

class LanguageHandler < BaseHandler
  class SubmissionError < Exception
  end

  NewFunction = 'newFunction'
  NewAlias = 'newAlias'

  ArgumentCountDescriptions = [
    'Nullary',
    'Unary',
    'Binary',
    'Ternary',
  ]

  def installHandlers
    WWWLib::RequestHandler.newBufferedObjectsGroup

    WWWLib::RequestHandler.menu('Add word', 'addWord', method(:addWord), nil, method(:isPrivileged))
    @viewWordsHandler = WWWLib::RequestHandler.menu('View lexicon', 'viewWords', method(:viewWords))
    WWWLib::RequestHandler.menu('Translate', 'translate', method(:translate))

    @editWordHandler = WWWLib::RequestHandler.handler('editWord', method(:editWord), 1)
    @submitWordHandler = WWWLib::RequestHandler.handler('submitWord', method(:submitWord))
    @deleteWordHandler = WWWLib::RequestHandler.handler('deleteWord', method(:deleteWord), 1)
    @regenerateWordHandler = WWWLib::RequestHandler.handler('regenerateWord', method(:regenerateWord), 1)
    @viewGroupHandler = WWWLib::RequestHandler.handler('viewGroup', method(:viewGroup), 1)
    @submitEditedWordHandler = WWWLib::RequestHandler.handler('submitEditedWord', method(:submitEditedWord))
    @submitTranslationHandler = WWWLib::RequestHandler.handler('submitTranslation', method(:submitTranslation))

    WWWLib::RequestHandler.getBufferedObjects.each do |handler|
      addHandler(handler)
    end
  end

  def lexicon
    return @database[:lexicon]
  end

  def addWord(request)
    privilegeCheck(request)
    title = 'Add a new word'
    output = renderWordForm(@submitWordHandler)
    return @generator.get(output, request, title)
  end

  def editWord(request)
    privilegeCheck(request)
    id = request.arguments.first.to_i
    result = lexicon.where(id: id).all
    if result.empty?
      argumentError
    end
    row = result.first
    wordFormContents = WordFormContents.new(row)
    title = "Edit \"#{wordFormContents.function}\""
    output = renderWordForm(@submitEditedWordHandler, wordFormContents)
    return @generator.get(output, request, title)
  end

  def submissionError(text)
    raise SubmissionError.new(text)
  end

  def wordIsUsed(word)
    return lexicon.where(word: word).count > 0
  end

  def generateWord(priority)
    usedWords = lexicon.select(:word).all.map { |x| x[:word] }
    unusedWords = Generator::Words[priority].reject do |word|
      usedWords.include?(word)
    end
    if unusedWords.empty?
      return nil
    end
    word = unusedWords[rand(unusedWords.size)]
    return word
  end

  def getTime
    return Time.now.utc
  end

  def processWordSubmission(request, editing = false)
    form = WordForm.new(request)
    if form.error
      argumentError
    end
    argumentCount = form.argumentCount.to_i
    doGenerateWord = form.generateWord.to_i == 1
    if ![NewFunction, NewAlias].include?(form.type)
      argumentError
    end
    priority = form.priority.to_i
    if priority < 0 || priority >= Generator::Words.size
      argumentError
    end
    @database.transaction do
      type = form.type.to_sym
      if !editing && lexicon.where(function_name: form.function).count > 0
        submissionError 'This function name is already taken.'
      end
      if doGenerateWord
        word = generateWord(priority)
        if word == nil
          submissionError 'There are no unused words left for the specified priority class.'
        end
      else
        word = form.word
        if !editing && wordIsUsed(word)
          submissionError 'The word you have specified is already taken.'
        end
      end
      if word.empty?
        submissionError 'You have not specified a word.'
      end
      if form.function.empty?
        submissionError 'You have not specified a function name.'
      end
      aliasDefinition = nil
      if form.type.to_sym == :newAlias
        aliasDefinition = form.alias
      end
      rank = form.groupRank
      if rank.empty?
        rank = nil
      else
        rank = rank.to_i
      end
      time = getTime
      data = {
        function_name: form.function,
        argument_count: argumentCount,
        word: word,
        description: form.description,
        alias_definition: aliasDefinition,
        group_name: form.group,
        group_rank: rank,
        last_modified: time,
      }
      if editing
        editId = form.id.to_i
        if lexicon.where(id: editId).count == 0
          submissionError 'Invalid word ID.'
        end
        lexicon.where(id: editId).update(data)
      else
        data[:time_added] = time
        lexicon.insert(data)
      end
    end
  end

  def submitWord(request)
    privilegeCheck(request)
    title = nil
    output = nil
    begin
      processWordSubmission(request)
      title, output = renderSubmissionConfirmation
    rescue SubmissionError => error
      title, output = renderSubmissionError(error.message)
    end
    return @generator.get(output, request, title)
  end

  def submitEditedWord(request)
    privilegeCheck(request)
    title = nil
    output = nil
    begin
      processWordSubmission(request, true)
      title, output = renderSubmissionConfirmation(true)
    rescue SubmissionError => error
      title, output = renderSubmissionError(error.message)
    end
    return @generator.get(output, request, title)
  end

  def viewWords(request)
    words = lexicon.order(:function_name).all
    title = 'Lexicon'
    output = renderWords(request, words)
    return @generator.get(output, request, title)
  end

  def deleteWord(request)
    privilegeCheck(request)
    id = request.arguments.first.to_i
    begin
      lexicon.where(id: id).delete
    rescue Sequel::Error
      argumentError
    end
    title = 'Word deleted'
    return @generator.get(renderDeletionConfirmation, request, title)
  end

  def generateWord(priority)
    usedWords = lexicon.select(:word).all.map { |x| x[:word] }
    return Generator.generateUnusedWord(usedWords, priority)
  end

  def regenerateWord(request)
    privilegeCheck(request)
    id = request.arguments.first.to_i
    function = nil
    @database.transaction do
      result = lexicon.where(id: id).all
      if result.empty?
        argumentError
      end
      row = result.first
      function = row[:function_name]
      oldWord = row[:word]
      priority = Generator.getPriority(oldWord)
      if priority == nil
        #plainError 'Unable to find the word in the lexicon.'
        priority = oldWord.size >= 4 ? 1 : 0
      end
      newWord = generateWord(priority)
      if newWord == nil
        plainError 'No space left in this priority class.'
      end
      lexicon.where(id: id).update(word: newWord, last_modified: getTime)
    end
    path = "#{request.referrer}##{function}"
    return WWWLib::HTTPReply.refer(path)
  end

  def viewGroup(request)
    group = request.arguments.first
    if group.empty?
      argumentError
    end
    words = lexicon.where(group_name: group).order_by(:group_rank).all
    if words.empty?
      argumentError
    end
    title = "Group \"#{group}\""
    output = renderWords(request, words)
    return @generator.get(output, request, title)
  end

  def translate(request)
    title, output = renderTranslationForm
    return @generator.get(output, request, title)
  end

  def submitTranslation(request)
    translationForm = TranslationForm.new(request)
    if translationForm.error
      argumentError
    end
    translator = Translator.new(lexicon)
    title = nil
    output = nil
    begin
      xsampaTranslation, ipaTranslation = translator.translate(translationForm.input)
      title, output = renderTranslation(xsampaTranslation, ipaTranslation)
    rescue Translator::Error => error
      title, output = renderTranslationError(error.message)
    end
    return @generator.get(output, request, title)
  end
end
