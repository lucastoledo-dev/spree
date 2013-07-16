Spree::Order.class_eval do
  def self.build_from_api(user, params)
    line_items = params.delete(:line_items_attributes) || {}
    shipments = params.delete(:shipments_attributes) || []

    ensure_country_id_from_api params[:ship_address_attributes]
    ensure_state_id_from_api params[:ship_address_attributes]

    ensure_country_id_from_api params[:bill_address_attributes]
    ensure_state_id_from_api params[:bill_address_attributes]

    order = create!(params)

    order.create_shipments_from_api(shipments)
    order.create_line_items_from_api(line_items)

    order.save!
    order
  end

  def create_shipments_from_api(shipments_hash)
    shipments_hash.each do |s|
      shipment = shipments.build
      shipment.tracking = s[:tracking]

      inventory_units = s[:inventory_units] || []
      inventory_units.each do |iu|
        self.class.ensure_variant_id_from_api(iu)

        unit = shipment.inventory_units.build
        unit.order = self
        unit.variant_id = iu[:variant_id]
      end

      shipment.shipping_method = Spree::ShippingMethod.find_by_name!(s[:shipping_method])
      shipment.save!

      shipment.adjustment.locked = true
      shipment.adjustment.amount = s[:cost].to_f
      shipment.adjustment.save
    end
  end

  def create_line_items_from_api(line_items_hash)
    line_items_hash.each_key do |k|
      line_item = line_items_hash[k]
      self.class.ensure_variant_id_from_api(line_item)
      self.add_variant(Spree::Variant.find(line_item[:variant_id]), line_item[:quantity])
    end
  end

  def self.ensure_variant_id_from_api(hash)
    unless hash[:variant_id]
      hash[:variant_id] = Spree::Variant.find_by_sku!(hash.delete(:sku)).id
    end
  end

  def self.ensure_country_id_from_api(address)
    return if address.nil? or address[:country_id] or address[:country].nil?

    search = {}
    if name = address[:country]['name']
      search[:name] = name
    elsif iso_name = address[:country]['iso_name']
      search[:iso_name] = iso_name.upcase
    elsif iso = address[:country]['iso']
      search[:iso] = iso.upcase
    elsif iso3 = address[:country]['iso3']
      search[:iso3] = iso3.upcase
    end

    address.delete(:country)
    address[:country_id] = Spree::Country.where(search).first!.id
  end

  def self.ensure_state_id_from_api(address)
    return if address.nil? or address[:state_id] or address[:state].nil?

    search = {}
    if name = address[:state]['name']
      search[:name] = name
    elsif abbr = address[:state]['abbr']
      search[:abbr] = abbr.upcase
    end

    address.delete(:state)
    address[:state_id] = Spree::State.where(search).first!.id
  end
end
