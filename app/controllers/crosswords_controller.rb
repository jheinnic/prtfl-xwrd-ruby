class CrosswordsController < ApplicationController
  respond_to :html, :json

  # GET /crosswords
  # GET /crosswords.json
  def index
    @crosswords = Crossword.all

    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => @crosswords }
    end
  end

  # GET /crosswords/1
  # GET /crosswords/1.json
  def show
    @crossword = Crossword.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @crossword }
    end
  end

  # GET /crosswords/new
  # GET /crosswords/new.json
  def new
    @crossword = Crossword.new(params[:crossword])
    @crossword.allocate_word_slots

    # respond_to do |format|
    #   format.html # new.html.erb
    #   format.json { render :json => @crossword }
    # end
    respond_with(@crossword)
  end

  # GET /crosswords/1/edit
  def edit
    @crossword = Crossword.find(params[:id])
  end

  # POST /crosswords
  # POST /crosswords.json
  def create
    logger.debug(params.inspect)
    @crossword = Crossword.new(params[:crossword])

    respond_to do |format|
      if @crossword.save
        format.html { redirect_to @crossword, :notice => 'Crossword was successfully created.' }
        format.json { render :json => @crossword, :status => :created, :location => @crossword }
      else
        format.html { render :action => "new" }
        format.json { render :json => @crossword.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /crosswords/1
  # PUT /crosswords/1.json
  def update
    @crossword = Crossword.find(params[:id])

    respond_to do |format|
      if @crossword.update_attributes(params[:crossword])
        format.html { redirect_to @crossword, :notice => 'Crossword was successfully updated.' }
        format.json { head :no_content }
      else
        format.html { render :action => "edit" }
        format.json { render :json => @crossword.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /crosswords/1
  # DELETE /crosswords/1.json
  def destroy
    @crossword = Crossword.find(params[:id])
    @crossword.destroy

    respond_to do |format|
      format.html { redirect_to crosswords_url }
      format.json { head :no_content }
    end
  end
end
