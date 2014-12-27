require 'sinatra'
require 'data_mapper'

DataMapper::Logger.new($stdout, :debug)
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/cost_splitter.db")

class Person
  include DataMapper::Resource

  property :id, Serial
  property :name, String

  has n, :person_expense_records

  def balance
    BalanceCalculator.call[id]
  end

  def to_s
    name
  end
end

class Expense
  include DataMapper::Resource

  property :id, Serial
  property :cost, Decimal, precision: 8, scale: 2
  property :item, String

  has n, :person_expense_records
  has n, :people, through: :person_expense_records
  belongs_to :person

  def user_list
    people.map {|x| x.name }.join(", ")
  end
end

class PersonExpenseRecord
  include DataMapper::Resource

  property :id, Serial

  belongs_to :expense
  belongs_to :person
end

class BalanceCalculator
  def self.call
    balances = {}

    # Set default balance to 0
    Person.each { |person| balances[person.id] = 0 }

    # Iterate over each expense
    Expense.each do |expense|

      # Increase the balance by the total cost for the purchaser
      purchaser_id = expense.person_id
      balances[purchaser_id] += expense.cost

      # Collect the number of non-purchaser users
      payer_list = expense.people.map { |person| person.id }
      payer_list.delete_if { |x| x == purchaser_id }
      payer_count = payer_list.length

      # Calculate share per user
      share_per_user = expense.cost / payer_count

      # Update balance for each user
      payer_list.each { |payer_id| balances[payer_id] -= share_per_user }
    end

    balances
  end
end

helpers do
  def display_as_currency(decimal)
    "$" + sprintf("%.2f", decimal)
  end
end

DataMapper.finalize.auto_upgrade!

get '/' do
  haml :index
end

get '/people' do
  @people = Person.all
  haml :people
end

get '/people/:id/edit' do
  @person = Person.get(params[:id])
  haml :edit_person
end

post '/people/:id/edit' do
  @person = Person.get(params[:id])
  @person.update(name: params[:name])

  redirect '/people'
end

post '/people' do
  Person.create(name: params[:name])
  redirect '/people'
end

get '/expenses' do
  @expenses = Expense.all
  @people = Person.all
  haml :expenses
end

post '/expenses' do
  expense = Expense.create(cost: params[:cost], item: params[:item], person_id: params[:person_id])

  params[:person_expense_record].each do |person_id|
    PersonExpenseRecord.create(person_id: person_id, expense_id: expense.id)
  end

  redirect '/expenses'
end
