class CrosswordsController < ApplicationController
  respond_to :html, :json

  # GET /crosswords
  # GET /crosswords.json
  def index
    @crosswords = Crossword.as_summary.all
    @crossword = Crossword.with_words.new(params[:crossword])
    @crossword.allocate_word_slots

    # respond_to do |format|
    #   format.html # index.html.erb
    #   format.json { render :json => @crosswords }
    # end
    respond_with @crosswords
  end

  # GET /crosswords/1
  # GET /crosswords/1.json
  def show
    @crossword = Crossword.with_words.where(:id => params[:id]).first()

    #  respond_to do |format|
    #    format.html # show.html.erb
    #    format.json { render :json => @crossword }
    #  end

    respond_with @crossword, :include => :word_items
  end

  # GET /crosswords/new
  # GET /crosswords/new.json
  def new
    @crossword = Crossword.with_words.new(params[:crossword])
    @crossword.allocate_word_slots

    # respond_to do |format|
    #   format.html # new.html.erb
    #   format.json { render :json => @crossword }
    # end
    respond_with @crossword
    # do |f|
    #   if request.xhr?
    #     f.html do 
    #       render :partial => "crosswords/form", :layout => false
    #     end
    #   end
    # end
  end

  # GET /crosswords/1/edit
  def edit
    @crossword = Crossword.where(:id => params[:id]).first()

    respond_with @crossword, :include => :word_items
  end

  # POST /crosswords
  # POST /crosswords.json
  def create
    @crossword = Crossword.create(params[:crossword])

    respond_with(@crossword, :include => :word_items)
  end

  # PUT /crosswords/1
  # PUT /crosswords/1.json
  def update
    @crossword = Crossword.find(params[:id])
    @crossword.update_attributes(params[:crossword])

    #if @crossword.update_attributes(params[:crossword])
    #  format.html { redirect_to @crossword, :notice => 'Crossword was successfully updated.' }
    #  format.json { head :no_content }
    #else
    #  format.html { render :action => "edit" }
    #  format.json { render :json => @crossword.errors, :status => :unprocessable_entity }
    #end

    respond_with(@crossword, :include => :word_items)
  end

  # DELETE /crosswords/1
  # DELETE /crosswords/1.json
  def destroy
    @crossword = Crossword.find(params[:id])
    @crossword.destroy

    # respond_to do |format|
    #   format.html { redirect_to crosswords_url }
    #   format.json { head :no_content }
    # end
  end
end
