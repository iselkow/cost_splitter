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
    "--"
  end

  def to_s
    name
  end
end

class Expense
  include DataMapper::Resource

  property :id, Serial
  property :cost, Decimal
  property :item, String

  has n, :person_expense_records
  belongs_to :person
end

class PersonExpenseRecord
  include DataMapper::Resource

  property :id, Serial

  belongs_to :expense
  belongs_to :person
end

DataMapper.finalize.auto_upgrade!

get '/' do
  haml :index
end

get '/people' do
  @people = Person.all
  haml :people
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
  Expense.create(cost: params[:cost], item: params[:item], person_id: params[:person_id])
  redirect '/expenses'
end
