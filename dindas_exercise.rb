# encoding: utf-8
#
# Dinda's Exercise Ruby App
#
# Written by André Camargo
# June 2016

CHART_OF_ACCOUNTS_CSV = <<CSV
10,0
3,345
2,234
1,123
4,0
CSV

CASH_BOOK_CSV = <<CSV
1,100
2,66
1,-500
3,55
1,-100
1,1377
4,-1
CSV

require 'minitest'
require 'csv'

class ChartOfAccounts
  attr_reader :accounts, :fees

  def initialize
    @accounts = {}
    @fees = []
  end

  def add_account(account_id, account_balance)
    account_id_to_i = account_id.to_i
    @accounts[account_id_to_i] = Account.new(account_id_to_i, account_balance)
  end

  def add_fee(condition, action)
    @fees << [condition, action]
  end

  def add_default_fee!
    fee_condition = Proc.new {|book_entry| book_entry.withdraw? }
    fee_action = Proc.new do |cash_book, book_entry|
      cash_book.add_book_entry book_entry.account.id, -500, is_fee: true
    end
    add_fee fee_condition, fee_action
  end

  def to_csv
    @accounts.
      values.
      sort {|a,b| a.id <=> b.id }.
      collect {|account| "#{account.id},#{account.balance_in_cents}" }.
      join("\n")
  end

  def self.import_balance_from_csv(text)
    chart_of_accounts = new
    CSV.parse(text, headers: false).each do |row|
      account_id, account_balance = row
      chart_of_accounts.add_account(account_id, account_balance)
    end
    chart_of_accounts
  end

  def self.import_balance_from_csv_file(path)
    import_balance_from_csv File.read(path)
  end
end

class Account
  attr_accessor :id
  attr_reader :balance_in_cents

  def initialize(account_id, account_balance)
    @id = account_id.to_i
    @balance_in_cents = account_balance.to_i
  end

  def update_balance(value)
    @balance_in_cents += value.to_i
  end
end

class BookEntry
  attr_accessor :account, :value

  def initialize(account, value)
    @account = account
    @value = value.to_i
    @account.update_balance(@value)
  end

  def withdraw?
    @value < 0
  end

  def to_csv
    "#{@account.id},#{@value}"
  end
end

class CashBook
  def initialize(chart_of_accounts)
    @book_entries = []
    @chart_of_accounts = chart_of_accounts
  end

  def add_book_entry(account_id, value, options={})
    options[:is_fee] = false unless options.has_key? :is_fee
    account_id_to_i = account_id.to_i
    if account = @chart_of_accounts.accounts[account_id_to_i]
      book_entry = BookEntry.new(account, value)
      @book_entries << book_entry
      @chart_of_accounts.fees.each do |fee|
        condition, action = fee
        action.call(self, book_entry) if condition.call(book_entry)
      end unless options[:is_fee]
    end
  end

  def to_csv
    @book_entries.collect(&:to_csv).join("\n")
  end

  def self.import_book_entries_from_csv(chart_of_accounts, text)
    cash_book = new(chart_of_accounts)
    CSV.parse(text, headers: false).each do |row|
      account_id, value = row
      cash_book.add_book_entry(account_id, value)
    end
    cash_book
  end

  def self.import_book_entries_from_csv_file(chart_of_accounts, path)
    self.import_book_entries_from_csv chart_of_accounts, path
  end
end

class Tax
  attr_accessor :condition, :action
end

class Cli
  def self.process(args, options)
    balance_filename_csv, cash_book_filename_csv = args

    return false unless balance_filename_csv &&
      File.exists?(balance_filename_csv) &&
      cash_book_filename_csv &&
      File.exists?(cash_book_filename_csv)

    @chart_of_accounts = ChartOfAccounts.import_balance_from_csv_file(balance_filename_csv)
    @chart_of_accounts.add_default_fee!

    @cash_book = CashBook.import_book_entries_from_csv_file(@chart_of_accounts, cash_book_filename_csv)
    puts "Here it is what you're waiting for:"
    puts
    puts @chart_of_accounts.to_csv
    puts
    true
  end

  def self.help(args, options)
    options[:default_contas_csv_path] = 'contas.csv' unless options.has_key?(:default_contas_csv_path)
    options[:default_transacoes_csv_path] = 'transacoes.csv' unless options.has_key?(:default_transacoes_csv_path)

    contas_csv_path, transacoes_csv_path = args

    if contas_csv_path.nil?
      puts "You didn't inform the balance CSV file."
      contas_csv_path = options[:default_contas_csv_path]
      puts "Using default #{contas_csv_path}"
    end
    unless File.exists?(contas_csv_path)
      puts "File #{contas_csv_path} doesn't exist."
      puts "So, I'm seeding some balance data for you ;-)"
      File.open(contas_csv_path, 'w+') do |file|
        file.write(CHART_OF_ACCOUNTS_CSV)
      end
      puts "File #{contas_csv_path} created"
    end

    puts
    if transacoes_csv_path.nil?
      puts "You didn't inform the cash book CSV file."
      transacoes_csv_path = options[:default_transacoes_csv_path]
      puts "Using default #{transacoes_csv_path}"
    end
    unless File.exists?(transacoes_csv_path)
      puts "File #{transacoes_csv_path} doesn't exist."
      puts "So, I'm seeding some book entries records for you ;-)"
      File.open(transacoes_csv_path, 'w+') do |file|
        file.write(CASH_BOOK_CSV)
      end
      puts "File #{transacoes_csv_path} created"
    end

    puts
    puts "Great! Now you can use the app running:"
    puts
    puts "$ ruby dindas_exercise.rb #{contas_csv_path} #{transacoes_csv_path}"
    puts
  end

  def self.run(args, options={})
    options[:default_contas_csv_path] = 'contas.csv' unless options.has_key?(:default_contas_csv_path)
    options[:default_transacoes_csv_path] = 'transacoes.csv' unless options.has_key?(:default_transacoes_csv_path)
    result = process(args, options)
    help(args, options) unless result
  end
end

# Tests --------------------------------------------------------------------

class ChartOfAccountsTest < MiniTest::Test
  def test_add_account
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_account 1, 123
    assert_equal "1,123", chart_of_accounts.to_csv
    chart_of_accounts.add_account 2, 234
    assert_equal "1,123\n2,234", chart_of_accounts.to_csv
  end

  def test_add_fee
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_default_fee!
    chart_of_accounts.add_account 1, 0
    
    cash_book = CashBook.new(chart_of_accounts)
    cash_book.add_book_entry 1, -100
    assert_equal "1,-600", chart_of_accounts.to_csv
  end
end

class AccountTest < MiniTest::Test
  def test_initialization
    account = Account.new('1', '123')
    assert_equal 1, account.id
    assert_equal 123, account.balance_in_cents
  end
end

class CashBookTest < MiniTest::Test
  def test_add_book_entry
    chart_of_accounts = ChartOfAccounts.new
    chart_of_accounts.add_account 1, 123
    chart_of_accounts.add_account 2, 0
    cash_book = CashBook.new(chart_of_accounts)
    cash_book.add_book_entry 1, 77
    assert_equal "1,77", cash_book.to_csv
    assert_equal "1,200\n2,0", chart_of_accounts.to_csv
    cash_book.add_book_entry 2, 77
    assert_equal "1,77\n2,77", cash_book.to_csv
    assert_equal "1,200\n2,77", chart_of_accounts.to_csv
  end

  def test_fixture_data_csv
    chart_of_accounts = ChartOfAccounts.import_balance_from_csv(CHART_OF_ACCOUNTS_CSV)
    chart_of_accounts.add_default_fee!
    cash_book = CashBook.import_book_entries_from_csv(chart_of_accounts, CASH_BOOK_CSV)
    assert_equal "1,0\n2,300\n3,400\n4,-501\n10,0", chart_of_accounts.to_csv
  end
end

class CliTest < MiniTest::Test
  def with_captured_stdout
    begin
      old_stdout = $stdout
      $stdout = StringIO.new('','w')
      yield
      $stdout.string
    ensure
      $stdout = old_stdout
    end
  end

  def setup
    @options = {
      default_contas_csv_path: 'teste_contas.csv',
      default_transacoes_csv_path: 'teste_transacoes.csv'
    }
  end

  def teardown
    @options.values.each do |filename|
      File.delete filename if File.exists?(filename)
    end
  end

  def test_no_csv_files
    output = with_captured_stdout do
      argv = []
      Cli.run(argv, @options)
    end
    assert_equal "You didn't inform the balance CSV file.\nUsing default teste_contas.csv\nFile teste_contas.csv doesn't exist.\nSo, I'm seeding some balance data for you ;-)\nFile teste_contas.csv created\n\nYou didn't inform the cash book CSV file.\nUsing default teste_transacoes.csv\nFile teste_transacoes.csv doesn't exist.\nSo, I'm seeding some book entries records for you ;-)\nFile teste_transacoes.csv created\n\nGreat! Now you can use the app running:\n\n$ ruby dindas_exercise.rb teste_contas.csv teste_transacoes.csv\n\n", output
  end

  def test_just_one_csv_file
    output = with_captured_stdout { Cli.run([@options[:default_contas_csv_path]], @options) }
    assert_equal "File teste_contas.csv doesn't exist.\nSo, I'm seeding some balance data for you ;-)\nFile teste_contas.csv created\n\nYou didn't inform the cash book CSV file.\nUsing default teste_transacoes.csv\nFile teste_transacoes.csv doesn't exist.\nSo, I'm seeding some book entries records for you ;-)\nFile teste_transacoes.csv created\n\nGreat! Now you can use the app running:\n\n$ ruby dindas_exercise.rb teste_contas.csv teste_transacoes.csv\n\n", output
  end

  def test_both_files_provided_but_they_dont_exist
    output = with_captured_stdout do
      argv = ['teste_contas.csv', 'teste_transacoes.csv']
      Cli.run(argv, @options)
    end
    assert_equal "File teste_contas.csv doesn't exist.\nSo, I'm seeding some balance data for you ;-)\nFile teste_contas.csv created\n\nFile teste_transacoes.csv doesn't exist.\nSo, I'm seeding some book entries records for you ;-)\nFile teste_transacoes.csv created\n\nGreat! Now you can use the app running:\n\n$ ruby dindas_exercise.rb teste_contas.csv teste_transacoes.csv\n\n", output
  end

  def test_both_files_provided_and_they_exist
    File.open(@options[:default_contas_csv_path], 'w') {|file| file.write(CHART_OF_ACCOUNTS_CSV) }
    File.open(@options[:default_transacoes_csv_path], 'w') {|file| file.write(CASH_BOOK_CSV) }
    output = with_captured_stdout do
      argv = [@options[:default_contas_csv_path], @options[:default_contas_csv_path]]
      Cli.run(argv, @options)
    end
    assert_equal "Here it is what you're waiting for:\n\n1,123\n2,234\n3,345\n4,0\n10,0\n\n", output
  end
end

# Script -------------------------------------------------------------------

if Minitest.run
  puts
  puts "Yay! All tests passed!"
  puts '-' * 80
  puts
  Cli.run(ARGV)
else
  puts
  puts "Tests failed! Aborting execution!"
  puts
end
