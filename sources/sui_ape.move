module sui_ape::sui_ape {
  use sui::object::{Self, UID, ID};
  use sui::transfer;
  use sui::tx_context::{Self, TxContext};
  use sui::event::emit;
  use sui::dynamic_object_field as dof;

  use std::string::{Self, String};
  // use std::option::{Self, Option};
  use std::vector;
  use std::hash::sha3_256 as hash;

  struct TAPE has store, copy, drop {
    url: String,
    description: String
  }

  struct APEsZoo has key, store {
    id: UID,
    apes: vector<TAPE>
  }

  struct Attribute has store, copy, drop {
    level: u8,
    hp: u64,
    atk: u64,
    def: u64,
    hit: u64
  }

  struct Ape has key, store {
    id: UID,
    n: u64,
    name: String,
    url: String,
    description: String,
    attribute: Attribute,
    /* 0 - normal, 1 - fighting, 2 - rest, 3 - dead */
    status: u8
  }

  struct Playground<phantom Ape> has key {
    id: UID
  }

  struct Listing has key, store {
    id: UID,
    owner: address,
    status: u8
  }

  struct ApeWrapper has key {
    id: UID,
    owner: address,
    ape: Ape
  }

  struct ApeIssueCap has key {
    id: UID,
    supply: u64,
    issued_counter: u64
  }

  struct ApeRegister has key {
    id: UID,
    ape_hash: vector<u8>
  }

  struct ApeMint has copy, drop {
    id: ID,
    url: String,
    mint_by: address
  }

  const MAX_SUPPLY: u64 = 10;

  const ETooManyNums: u64 = 0;
  const NotApeOwner: u64 = 1;
  const ApeShouldBeNormal: u64 = 2;

  fun init(ctx: &mut TxContext) {
    let id = object::new(ctx);
    let ape_hash = hash(object::uid_to_bytes(&id));

    let issuer_cap = ApeIssueCap {
      id: object::new(ctx),
      supply: 0,
      issued_counter: 0,
    };

    let apes = vector<TAPE>[
      TAPE {
        description: string::utf8(b"#3954"),
        url: string::utf8(b"https://img.seadn.io/files/a869b6f365fa14f6b039e6ea83415427.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#2974"),
        url: string::utf8(b"https://img.seadn.io/files/ea93d1afdcdc26942fe8f3215fadfd60.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#7404"),
        url: string::utf8(b"https://img.seadn.io/files/47ae9300181f827bae236bc00768dbbe.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#7504"),
        url: string::utf8(b"https://img.seadn.io/files/33e8447004630b8ee8572e26990849b2.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#4827"),
        url: string::utf8(b"https://img.seadn.io/files/9f7c181a826da175b3666531ffea8f3e.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#4174"),
        url: string::utf8(b"https://img.seadn.io/files/9109bc226cce23a5c2018ad7ad595718.png?fit=max&w=1000")
      },
      TAPE {
        description: string::utf8(b"#4751"),
        url: string::utf8(b"https://img.seadn.io/files/6e75c1c5568bd5efc84ca297ae862162.png?fit=max&w=1000")
      }
    ];

    transfer::share_object(APEsZoo {
      id: object::new(ctx),
      apes
    });
    transfer::share_object(issuer_cap);
    transfer::share_object(ApeRegister {
      id,
      ape_hash
    }); 
    create_playground(ctx);
  }

  fun create_playground(ctx: &mut TxContext) {
    let id = object::new(ctx); 
    transfer::share_object(Playground<Ape> { id });
  }

  public entry fun mint(reg: &mut ApeRegister, cap: &mut ApeIssueCap, appesZoo: &APEsZoo, name: String, ctx: &mut TxContext) {
    let n = cap.issued_counter;
    cap.issued_counter = n + 1;
    cap.supply = cap.supply + 1;
    assert!(n <= MAX_SUPPLY, ETooManyNums); 

    let id = object::new(ctx);
    vector::append(&mut reg.ape_hash, object::uid_to_bytes(&id));
    vector::push_back(&mut reg.ape_hash, 1);
    reg.ape_hash = hash(reg.ape_hash);
    let rng = *vector::borrow(&reg.ape_hash, 0);
    let ape = *vector::borrow(&appesZoo.apes, (((rng as u64) % vector::length(&appesZoo.apes) ) as u64));

    let sender = tx_context::sender(ctx);

    emit(ApeMint {
      id: object::uid_to_inner(&id),
      url: ape.url,
      mint_by: sender
    });

    transfer::transfer(Ape {
      id,
      n,
      name,
      url: ape.url,
      description: ape.description,
      status: 0,
      attribute: Attribute {
        level: 1,
        hp: 50 - ((rng as u64) % 15),
        atk: 10 - ((rng as u64) % 8),
        def: 10 - ((rng as u64) % 8),
        hit: 100 - ((rng as u64) % 85),
      }
    }, sender); 
  }

  public entry fun request_fight(self: Ape, playground: &mut Playground<Ape>, ctx: &mut TxContext) {
    assert!(self.status == 0, ApeShouldBeNormal);

    let id = object::new(ctx);
    let owner = tx_context::sender(ctx);
    let listing = Listing {
      id, owner, status: 0
    };

    dof::add(&mut listing.id, true, self);
    dof::add(&mut playground.id, object::id(&listing), listing);
  }

  public entry fun cancel_request_fight(item_id: ID, playground: &mut Playground<Ape>, ctx: &mut TxContext) {
    let Listing { id, owner, status: _ } = dof::remove<ID, Listing>(&mut playground.id, item_id);
    let item: Ape = dof::remove(&mut id, true);

    assert!(tx_context::sender(ctx) == owner, NotApeOwner);

    object::delete(id);

    transfer::transfer(item, tx_context::sender(ctx));
  }

  public entry fun fight(playground: &mut Playground<Ape>, self_listing_id: ID, opponent_listing_id: ID) {
    let self = dof::remove<ID, Listing>(&mut playground.id, self_listing_id);
    let self_ape = dof::remove<bool, Ape>(&mut self.id, true);
    let opponent = dof::remove<ID, Listing>(&mut playground.id, opponent_listing_id);
    let opponent_ape = dof::remove<bool, Ape>(&mut opponent.id, true);

    if (self_ape.attribute.atk > opponent_ape.attribute.atk) {
      self.status = 1;
      opponent.status = 2;
      dof::add(&mut self.id, true, self_ape);
      dof::add(&mut playground.id, object::id(&self), self);
      dof::add(&mut opponent.id, true, opponent_ape);
      dof::add(&mut playground.id, object::id(&opponent), opponent);
    } else {
      self.status = 2;
      opponent.status = 1;
      dof::add(&mut self.id, true, self_ape);
      dof::add(&mut playground.id, object::id(&self), self);
      dof::add(&mut opponent.id, true, opponent_ape);
      dof::add(&mut playground.id, object::id(&opponent), opponent);
    };   
  }

  entry fun add_ape(appesZoo: &mut APEsZoo, description: String, url: String) {
    vector::push_back(&mut appesZoo.apes, TAPE {
      description,
      url,
    })
  }

  public entry fun burn(cap: &mut ApeIssueCap, ape: Ape) {
    let Ape { id, n: _, url: _, description: _, attribute: _, name: _, status: _ } = ape;
    cap.supply = cap.supply - 1;
    object::delete(id);
  }
}