var CPU;

CPU = (function() {

  /*
  16k ram
  Bytes, Words, Addressing:
  8 bit bytes, 16 bit words in lobyte-hibyte representation (Little-Endian).
  16 bit address range, operands follow instruction codes.
   */
  CPU.prototype.RAM_SIZE = 0xFFFF;

  CPU.prototype.SP_INIT_VAL = 0xFD;

  CPU.prototype.PC_INIT_VAL = 0xFFFC;

  CPU.prototype.BASE_STACK_ADDR = 0x100;

  CPU.prototype.VECTOR_TABLE = {
    NMI: 0xFFFA,
    RST: 0xFFFC,
    IRQ: 0xFFFE
  };

  CPU.prototype.READ_LENGTH = {
    L: 8,
    HL: 16
  };

  CPU.prototype.ADDRESSING_MODE = {
    ACCUMULATOR: 'ACC',
    IMMEDIATE: 'IMM',
    IMPLIED: 'IMP'
  };

  function CPU(ram) {
    var i, ref, x;
    this.ram = ram != null ? ram : [];
    for (x = i = 0, ref = CPU.prototype.RAM_SIZE; 0 <= ref ? i <= ref : i >= ref; x = 0 <= ref ? ++i : --i) {
      this.ram[x] = 0;
    }
    this.PC = CPU.prototype.PC_INIT_VAL;
    this.AC = 0;
    this.XR = 0;
    this.YR = 0;
    this.SR = 0;
    this.SP = CPU.prototype.SP_INIT_VAL;
    this.N = 0;
    this.V = 0;
    this.U = 1;
    this.B = 0;
    this.D = 0;
    this.I = 0;
    this.Z = 0;
    this.C = 0;
    this.cycles = 0;
  }

  CPU.prototype.init = function() {
    this.PC = this.PC_INIT_VAL;
    this.SP = this.SP_INIT_VAL;
    return this.cycles = 0;
  };

  CPU.prototype.clear = function() {
    var i, ref, results, x;
    results = [];
    for (x = i = 0, ref = CPU.prototype.RAM_SIZE; 0 <= ref ? i <= ref : i >= ref; x = 0 <= ref ? ++i : --i) {
      results.push(this.ram[x] = 0);
    }
    return results;
  };

  CPU.prototype.read = function(address, readingLength) {
    var h, l;
    if (readingLength === CPU.prototype.READ_LENGTH.HL) {
      l = this.ram[address];
      h = this.ram[address + 1];
      return h << 8 | l;
    } else {
      return this.ram[address];
    }
  };


  /*
    Stack operations
   */

  CPU.prototype.push = function(value) {
    if (value > 0xFF) {
      this.push(value >> 8);
      return this.push(value & 0xFF);
    } else {
      this.ram[CPU.prototype.BASE_STACK_ADDR + this.SP] = value;
      this.SP--;
      return this.SP &= 0xFF;
    }
  };

  CPU.prototype.pop = function() {
    this.SP++;
    this.SP &= 0xFF;
    return this.ram[CPU.prototype.BASE_STACK_ADDR + this.SP];
  };

  CPU.prototype.getSR = function() {
    return this.N << 7 | this.V << 6 | this.U << 5 | this.B << 4 | this.D << 3 | this.I << 2 | this.Z << 1 | this.C;
  };

  CPU.prototype.setSR = function(SR) {
    this.N = SR >> 7 & 0x1;
    this.V = SR >> 6 & 0x1;
    this.U = SR >> 5 & 0x1;
    this.B = SR >> 4 & 0x1;
    this.D = SR >> 3 & 0x1;
    this.I = SR >> 2 & 0x1;
    this.Z = SR >> 1 & 0x1;
    return this.C = SR & 0x1;
  };


  /*
   Interruption
   */

  CPU.prototype.interrupt = function(interruptType) {
    this.push(this.PC);
    this.push(this.getSR());
    this.PC = this.read(interruptType, CPU.prototype.READ_LENGTH.HL);
    this.I = 1;
    return this.cycles += 7;
  };

  CPU.prototype.NMI = function() {
    return this.interrupt(CPU.prototype.VECTOR_TABLE.NMI);
  };

  CPU.prototype.IRQ = function() {
    return this.interrupt(CPU.prototype.VECTOR_TABLE.IRQ);
  };

  CPU.prototype.RST = function() {
    return this.interrupt(CPU.prototype.VECTOR_TABLE.RST);
  };

  CPU.prototype.printRegisters = function() {
    return console.log('AC=', this.AC, '(= BDC', this.AC.toString(16), ') V=', this.V, 'C=', this.C, 'N=', this.N, 'Z=', this.Z);
  };


  /*
    Addressing modes
   */

  CPU.prototype.accumulator = function() {
    return {
      operand: this.AC,
      address: CPU.prototype.ADDRESSING_MODE.ACCUMULATOR,
      bytes: 0
    };
  };

  CPU.prototype.absolute = function(oper) {
    return {
      operand: this.ram[oper],
      address: oper,
      bytes: 2
    };
  };

  CPU.prototype.absoluteX = function(oper) {
    return {
      operand: this.ram[oper + this.XR],
      address: oper + this.XR,
      bytes: 2
    };
  };

  CPU.prototype.absoluteY = function(oper) {
    return {
      operand: this.ram[oper + this.YR],
      address: oper + this.YR,
      bytes: 2
    };
  };

  CPU.prototype.immediate = function(oper) {
    return {
      operand: oper,
      address: CPU.prototype.ADDRESSING_MODE.IMMEDIATE,
      bytes: 1
    };
  };

  CPU.prototype.implied = function(oper) {
    return {
      operand: this.AC,
      address: CPU.prototype.ADDRESSING_MODE.IMPLIED,
      bytes: 0
    };
  };

  CPU.prototype.indirect = function(oper) {
    return {
      operand: this.ram[this.ram[oper]],
      address: this.ram[oper],
      bytes: 2
    };
  };

  CPU.prototype.indirectX = function(oper) {
    return {
      operand: this.ram[this.ram[(oper & 0x00FF) + this.XR]],
      address: this.ram[(oper & 0x00FF) + this.XR],
      bytes: 1
    };
  };

  CPU.prototype.indirectY = function(oper) {
    return {
      operand: this.ram[this.ram[(oper & 0x00FF) + this.YR]],
      address: this.ram[(oper & 0x00FF) + this.YR],
      bytes: 1
    };
  };

  CPU.prototype.relative = function(oper) {
    return {
      operand: this.ram[this.PC + oper],
      address: this.PC + oper,
      bytes: 1
    };
  };

  CPU.prototype.zeropage = function(oper) {
    return {
      operand: this.ram[oper & 0x00FF],
      address: oper & 0x00FF,
      bytes: 1
    };
  };

  CPU.prototype.zeropageX = function(oper) {
    return {
      operand: this.ram[(oper + this.XR) & 0x00FF],
      address: oper + this.XR,
      bytes: 1
    };
  };

  CPU.prototype.zeropageY = function(oper) {
    return {
      operand: this.ram[(oper + this.YR) & 0x00FF],
      address: oper + this.YR,
      bytes: 1
    };
  };

  CPU.prototype.addressing = function() {
    if (arguments.length === 2) {
      return arguments[1];
    } else {
      return this.immediate;
    }
  };

  CPU.stepInfo = {
    operand: 0x00,
    addressMode: null
  };

  CPU.prototype.step = function() {
    var operand;
    operand = this.ram[this.PC];
    this.stepInfo.operand = operand;
    return this.stepInfo.addressMode = this.immediate(operand);
  };

  CPU.prototype.accumulate = function(src, dst, carry) {
    return src + dst + carry;
  };

  CPU.prototype.compare = function(src, dest) {
    var diff;
    diff = src - dest;
    this.setZN(diff);
    if (diff >= 0) {
      this.C = 1;
    } else {
      this.C = 0;
    }
    return diff;
  };

  CPU.prototype.setZ = function(oper) {
    return this.Z = oper === 0 ? 1 : 0;
  };

  CPU.prototype.setN = function(oper) {
    return this.N = (oper & 0x80) !== 0 ? 1 : 0;
  };

  CPU.prototype.setZN = function(oper) {
    this.setZ(oper);
    return this.setN(oper);
  };

  CPU.prototype.addCycleOnBranch = function(stepInfo) {
    return this.cycles += 1;
  };

  CPU.prototype.run = function() {
    var addressMode, instruction, oprcode, oprcodeInfo;
    oprcode = this.ram[this.PC];
    oprcodeInfo = CPU.prototype.OPRCODES[oprcode];
    console.log("OPC:", oprcodeInfo.instruction);
    instruction = oprcodeInfo.instruction;
    addressMode = oprcodeInfo.addressMode.call(this, oprcode + 1);
    instruction.call(this, addressMode);
    return this.PC += addressMode.bytes + 1;
  };


  /*
    Instructions
   */

  CPU.prototype.CLD = function() {
    return this.D = 0;
  };

  CPU.prototype.LDA = function(oper) {
    return this.AC = this.addressing(arguments)(oper);
  };


  /*
  ADC  Add Memory to Accumulator with Carry
  
     A + M + C -> A, C                N Z C I D V
                                      + + + - - +
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     ADC #oper     69    2     2
     zeropage      ADC oper      65    2     3
     zeropage,X    ADC oper,X    75    2     4
     absolute      ADC oper      6D    3     4
     absolute,X    ADC oper,X    7D    3     4*
     absolute,Y    ADC oper,Y    79    3     4*
     (indirect,X)  ADC (oper,X)  61    2     6
     (indirect),Y  ADC (oper),Y  71    2     5*
   */

  CPU.prototype.ADC = function(stepInfo) {
    var H4b, operand;
    operand = stepInfo.operand;
    this.AC = this.accumulate(operand, this.AC, this.C);
    console.log('@AC', this.AC);
    this.C = this.AC > 0xFF ? 1 : 0;
    this.setZN(this.AC);
    H4b = this.AC / 0x10;
    this.V = H4b >= -8 & H4b <= 7 ? 0 : 1;
    if (this.V === 1) {
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!');
    }
    console.log('@H4b is', H4b.toString(16));
    this.AC = this.AC & 0xFF;
    return this.printRegisters();
  };


  /*
  AND Memory with Accumulator
  
     A AND M -> A                     N Z C I D V
                                      + + - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     AND #oper     29    2     2
     zeropage      AND oper      25    2     3
     zeropage,X    AND oper,X    35    2     4
     absolute      AND oper      2D    3     4
     absolute,X    AND oper,X    3D    3     4*
     absolute,Y    AND oper,Y    39    3     4*
     (indirect,X)  AND (oper,X)  21    2     6
     (indirect),Y  AND (oper),Y  31    2     5*
   */

  CPU.prototype.AND = function(stepInfo) {
    var operand;
    operand = stepInfo.operand;
    this.AC = this.AC & operand & 0xFF;
    return this.setZN(this.AC);
  };


  /*
  ASL  Shift Left One Bit (Memory or Accumulator)
  
     C <- [76543210] <- 0             N Z C I D V
                                      + + + - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     accumulator   ASL A         0A    1     2
     zeropage      ASL oper      06    2     5
     zeropage,X    ASL oper,X    16    2     6
     absolute      ASL oper      0E    3     6
     absolute,X    ASL oper,X    1E    3     7
   */

  CPU.prototype.ASL = function(stepInfo) {
    var addressingMode, operand;
    operand = stepInfo.operand;
    addressingMode = stepInfo.addressMode;
    this.C = (operand >> 7) & 1;
    operand <<= 1;
    if (addressingMode.address === CPU.prototype.ADDRESSING_MODE.ACCUMULATOR) {
      this.AC = operand;
    } else {
      this.ram[operand];
    }
    return this.setZN(operand);
  };


  /*
    BCC  Branch on Carry Clear
  
     branch on C = 0                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCC oper      90    2     2**
   */

  CPU.prototype.BCC = function(stepInfo) {
    if (this.C === 0) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BCS  Branch on Carry Set
  
     branch on C = 1                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BCS oper      B0    2     2**
   */

  CPU.prototype.BCS = function(stepInfo) {
    if (this.C === 1) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BEQ  Branch on Result Zero
  
     branch on Z = 1                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BEQ oper      F0    2     2**
   */

  CPU.prototype.BEQ = function(stepInfo) {
    if (this.Z === 1) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BIT  Test Bits in Memory with Accumulator
  
     bits 7 and 6 of operand are transfered to bit 7 and 6 of SR (N,V);
     the zeroflag is set to the result of operand AND accumulator.
  
     A AND M, M7 -> N, M6 -> V        N Z C I D V
                                     M7 + - - - M6
  
     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     zeropage      BIT oper      24    2     3
     absolute      BIT oper      2C    3     4
   */

  CPU.prototype.BIT = function(stepInfo) {
    console.log(stepInfo);
    this.N = stepInfo.operand >> 7 & 1;
    this.V = stepInfo.operand >> 6 & 1;
    return this.Z = stepInfo.operand & this.AC;
  };


  /*
    BMI  Branch on Result Minus
  
     branch on N = 1                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cycles
     --------------------------------------------
     relative      BMI oper      30    2     2**
   */

  CPU.prototype.BMI = function(stepInfo) {
    if (this.N === 1) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BNE  Branch on Result not Zero
  
     branch on Z = 0                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BNE oper      D0    2     2**
   */

  CPU.prototype.BNE = function(stepInfo) {
    if (this.Z === 0) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BPL  Branch on Result Plus
  
     branch on N = 0                  N Z C I D V
                                      - - - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     relative      BPL oper      10    2     2**
   */

  CPU.prototype.BPL = function(stepInfo) {
    if (this.N === 0) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BRK  Force Break
  
      interrupt,                       N Z C I D V
      push PC+2, push SR               - - - 1 - -
  
        addressing    assembler    opc  bytes  cycles
      --------------------------------------------
      implied       BRK           00    1     7
   */

  CPU.prototype.BRK = function(stepInfo) {
    return this.interrupt(CPU.prototype.VECTOR_TABLE.NMI);
  };


  /*
    BVC  Branch on Overflow Clear
  
      branch on V = 0                  N Z C I D V
    - - - - - -
  
    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    relative      BVC oper      50    2     2**
   */

  CPU.prototype.BVC = function(stepInfo) {
    if (this.V === 0) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
    BVS  Branch on Overflow Set
  
    branch on V = 1                  N Z C I D V
  - - - - - -
  
  addressing    assembler    opc  bytes  cycles
  --------------------------------------------
  relative      BVC oper      70    2     2**
   */

  CPU.prototype.BVS = function(stepInfo) {
    if (this.V === 1) {
      this.PC = stepInfo.addressMode.address;
      return this.addCycleOnBranch(stepInfo);
    }
  };


  /*
      CLC  Clear Carry Flag
  
        0 -> C                           N Z C I D V
    - - 0 - - -
  
    addressing    assembler    opc  bytes  cycles
    --------------------------------------------
    implied       CLC           18    1     2
   */

  CPU.prototype.CLC = function(stepInfo) {
    this.C = 0;
    return this.cycles += 2;
  };


  /*
  CLI  Clear Interrupt Disable Bit
  
     0 -> I                           N Z C I D V
                                      - - - 0 - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLI           58    1     2
   */

  CPU.prototype.CLI = function(stepInfo) {
    this.I = 0;
    return this.cycles += 2;
  };


  /*
  CLV  Clear Overflow Flag
  
     0 -> V                           N Z C I D V
                                      - - - - - 0
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       CLV           B8    1     2
   */

  CPU.prototype.CLV = function(stepInfo) {
    this.V = 0;
    return this.cycles += 2;
  };


  /*
    CMP  Compare Memory with Accumulator
  
      A - M                            N Z C I D V
                                       + + + - - -
  
    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     CMP #oper     C9    2     2
    zeropage      CMP oper      C5    2     3
    zeropage,X    CMP oper,X    D5    2     4
    absolute      CMP oper      CD    3     4
    absolute,X    CMP oper,X    DD    3     4*
    absolute,Y    CMP oper,Y    D9    3     4*
    (indirect,X)  CMP (oper,X)  C1    2     6
    (indirect),Y  CMP (oper),Y  D1    2     5*
   */

  CPU.prototype.CMP = function(stepInfo) {
    return this.compare(this.AC, stepInfo.operand);
  };


  /*
  CPX  Compare Memory and Index X
  
      X - M                            N Z C I D V
                                       + + + - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPX #oper     E0    2     2
  zeropage      CPX oper      E4    2     3
  absolute      CPX oper      EC    3     4
   */

  CPU.prototype.CPX = function(stepInfo) {
    return this.compare(this.XR, stepInfo.operand);
  };


  /*
  CPY  Compare Memory and Index Y
  
      Y - M                            N Z C I D V
                                       + + + - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     CPY #oper     C0    2     2
  zeropage      CPY oper      C4    2     3
  absolute      CPY oper      CC    3     4
   */

  CPU.prototype.CPY = function(stepInfo) {
    return this.compare(this.YR, stepInfo.operand);
  };


  /*
  DEC  Decrement Memory by One
  
     M - 1 -> M                       N Z C I D V
                                      + + - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     zeropage      DEC oper      C6    2     5
     zeropage,X    DEC oper,X    D6    2     6
     absolute      DEC oper      CE    3     3
     absolute,X    DEC oper,X    DE    3     7
   */

  CPU.prototype.DEC = function(stepInfo) {
    var decreased;
    decreased = stepInfo.operand - 1;
    this.ram[stepInfo.addressMode.address] = decreased;
    return this.setZN(decreased);
  };


  /*
  DEX  Decrement Index X by One
  
       X - 1 -> X                       N Z C I D V
                                        + + - - - -
  
       addressing    assembler    opc  bytes  cyles
       --------------------------------------------
       implied       DEC           CA    1     2
   */

  CPU.prototype.DEX = function(stepInfo) {
    return this.setZN(this.XR--);
  };


  /*
  DEY  Decrement Index Y by One
  
     Y - 1 -> Y                       N Z C I D V
                                      + + - - - -
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     implied       DEC           88    1     2
   */

  CPU.prototype.DEY = function(stepInfo) {
    return this.setZN(this.YR--);
  };


  /*
  EOR  Exclusive-OR Memory with Accumulator
  
   A EOR M -> A                     N Z C I D V
                                    + + - - - -
  
   addressing    assembler    opc  bytes  cyles
   --------------------------------------------
   immidiate     EOR #oper     49    2     2
   zeropage      EOR oper      45    2     3
   zeropage,X    EOR oper,X    55    2     4
   absolute      EOR oper      4D    3     4
   absolute,X    EOR oper,X    5D    3     4*
   absolute,Y    EOR oper,Y    59    3     4*
   (indirect,X)  EOR (oper,X)  41    2     6
   (indirect),Y  EOR (oper),Y  51    2     5*
   */

  CPU.prototype.EOR = function(stepInfo) {
    this.AC ^= stepInfo.operand;
    this.AC &= 0xFF;
    return this.setZN(this.AC);
  };


  /*
  INC  Increment Memory by One
  
  M + 1 -> M                       N Z C I D V
                                  + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      INC oper      E6    2     5
  zeropage,X    INC oper,X    F6    2     6
  absolute      INC oper      EE    3     6
  absolute,X    INC oper,X    FE    3     7
   */

  CPU.prototype.INC = function(stepInfo) {
    var increased;
    increased = stepInfo.operand + 1;
    this.ram[stepInfo.addressMode.address] = increased;
    return this.setZN(increased);
  };


  /*
  INX  Increment Index X by One
  
  X + 1 -> X                       N Z C I D V
                                  + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INX           E8    1     2
   */

  CPU.prototype.INX = function(stepInfo) {
    return this.setZN(this.XR++);
  };


  /*
  
  INY  Increment Index Y by One
  
  Y + 1 -> Y                       N Z C I D V
                                  + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       INY           C8    1     2
   */

  CPU.prototype.INY = function(stepInfo) {
    return this.setZN(this.YR++);
  };


  /*
  
  JMP  Jump to New Location
  
  (PC+1) -> PCL                    N Z C I D V
  (PC+2) -> PCH                    - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JMP oper      4C    3     3
  indirect      JMP (oper)    6C    3     5
   */

  CPU.prototype.JMP = function(stepInfo) {
    return this.PC = stepInfo.operand;
  };


  /*
  
  JSR  Jump to New Location Saving Return Address
  
  push (PC+2),                     N Z C I D V
  (PC+1) -> PCL                    - - - - - -
  (PC+2) -> PCH
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  absolute      JSR oper      20    3     6
   */

  CPU.prototype.JSP = function(stepInfo) {
    this.push(this.PC);
    return this.PC = stepInfo.operand;
  };


  /*
  LDX  Load Index X with Memory
  
  M -> X                           N Z C I D V
                                   + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDX #oper     A2    2     2
  zeropage      LDX oper      A6    2     3
  zeropage,Y    LDX oper,Y    B6    2     4
  absolute      LDX oper      AE    3     4
  absolute,Y    LDX oper,Y    BE    3     4*
   */

  CPU.prototype.LDX = function(stepInfo) {
    this.XR = stepInfo.operand;
    return this.setZN(this.XR);
  };


  /*
  
  LDY  Load Index Y with Memory
  
  M -> Y                           N Z C I D V
                                   + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     LDY #oper     A0    2     2
  zeropage      LDY oper      A4    2     3
  zeropage,X    LDY oper,X    B4    2     4
  absolute      LDY oper      AC    3     4
  absolute,X    LDY oper,X    BC    3     4*
   */

  CPU.prototype.LDY = function(stepInfo) {
    this.YR = stepInfo.operand;
    return this.setZN(this.YR);
  };


  /*
  LSR  Shift One Bit Right (Memory or Accumulator)
  
  0 -> [76543210] -> C             N Z C I D V
                                   - + + - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   LSR A         4A    1     2
  zeropage      LSR oper      46    2     5
  zeropage,X    LSR oper,X    56    2     6
  absolute      LSR oper      4E    3     6
  absolute,X    LSR oper,X    5E    3     7
   */

  CPU.prototype.LSR = function(stepInfo) {
    var addressingMode, operand;
    operand = stepInfo.operand;
    addressingMode = stepInfo.addressMode;
    this.C = operand & 1;
    operand >>= 1;
    if (addressingMode.address === CPU.prototype.ADDRESSING_MODE.ACCUMULATOR) {
      this.AC = operand;
    } else {
      this.ram[operand];
    }
    return this.setZN(operand);
  };


  /*
  
  NOP  No Operation
  
  ---                              N Z C I D V
                                - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       NOP           EA    1     2
   */

  CPU.prototype.NOP = function(stepInfo) {

    /*
    
    ORA  OR Memory with Accumulator
    
    A OR M -> A                      N Z C I D V
                                  + + - - - -
    
    addressing    assembler    opc  bytes  cyles
    --------------------------------------------
    immidiate     ORA #oper     09    2     2
    zeropage      ORA oper      05    2     3
    zeropage,X    ORA oper,X    15    2     4
    absolute      ORA oper      0D    3     4
    absolute,X    ORA oper,X    1D    3     4*
    absolute,Y    ORA oper,Y    19    3     4*
    (indirect,X)  ORA (oper,X)  01    2     6
    (indirect),Y  ORA (oper),Y  11    2     5*
     */
  };

  CPU.prototype.ORA = function(stepInfo) {
    this.AC |= stepInfo.operand;
    return this.setZN(this.AC);
  };


  /*
  
  PHA  Push Accumulator on Stack
  
  push A                           N Z C I D V
                                - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHA           48    1     3
   */

  CPU.prototype.PHA = function(stepInfo) {
    return this.push(this.AC);
  };


  /*
  
  PHP  Push Processor Status on Stack
  
  push SR                          N Z C I D V
                                - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           08    1     3
   */

  CPU.prototype.PHP = function(stepInfo) {
    return this.push(this.getSR());
  };


  /*
  
  PLA  Pull Accumulator from Stack
  
  pull A                           N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PLA           68    1     4
   */

  CPU.prototype.PLA = function(stepInfo) {
    this.AC = this.pop();
    return this.setZN(this.AC);
  };


  /*
  
  PLP  Pull Processor Status from Stack
  
  pull SR                          N Z C I D V
                                from stack
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       PHP           28    1     4
   */

  CPU.prototype.PLP = function(stepInfo) {
    var sr;
    sr = this.pop();
    return this.setSR(sr);
  };


  /*
  
  ROL  Rotate One Bit Left (Memory or Accumulator)
  
  C <- [76543210] <- C             N Z C I D V
                                + + + - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROL A         2A    1     2
  zeropage      ROL oper      26    2     5
  zeropage,X    ROL oper,X    36    2     6
  absolute      ROL oper      2E    3     6
  absolute,X    ROL oper,X    3E    3     7
   */

  CPU.prototype.ROL = function(stepInfo) {
    var addressingMode, operand;
    operand = stepInfo.operand;
    addressingMode = stepInfo.addressMode;
    this.C = (operand >> 7) & 1;
    operand <<= 1;
    operand += this.C;
    if (addressingMode.address === CPU.prototype.ADDRESSING_MODE.ACCUMULATOR) {
      this.AC = operand;
    } else {
      this.ram[operand];
    }
    return this.setZN(operand);
  };


  /*
  
  ROR  Rotate One Bit Right (Memory or Accumulator)
  
  C -> [76543210] -> C             N Z C I D V
                                + + + - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  accumulator   ROR A         6A    1     2
  zeropage      ROR oper      66    2     5
  zeropage,X    ROR oper,X    76    2     6
  absolute      ROR oper      6E    3     6
  absolute,X    ROR oper,X    7E    3     7
   */

  CPU.prototype.ROR = function(stepInfo) {
    var addressingMode, operand, topBit;
    operand = stepInfo.operand;
    addressingMode = stepInfo.addressMode;
    topBit = operand & 1;
    operand >>= 1;
    operand += topBit << 7;
    this.C = topBit;
    if (addressingMode.address === CPU.prototype.ADDRESSING_MODE.ACCUMULATOR) {
      this.AC = operand;
    } else {
      this.ram[operand];
    }
    return this.setZN(operand);
  };


  /*
  
  RTI  Return from Interrupt
  
  pull SR, pull PC                 N Z C I D V
                                from stack
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTI           40    1     6
   */

  CPU.prototype.RTI = function(stepInfo) {
    this.setSR(this.pop());
    return this.PC = this.pop();
  };


  /*
  
  RTS  Return from Subroutine
  
  pull PC, PC+1 -> PC              N Z C I D V
                                - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       RTS           60    1     6
   */

  CPU.prototype.RTS = function(stepInfo) {
    return this.PC = this.pop() + 1;
  };


  /*
  
  SBC  Subtract Memory from Accumulator with Borrow
  
  A - M - C -> A                   N Z C I D V
                                + + + - - +
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  immidiate     SBC #oper     E9    2     2
  zeropage      SBC oper      E5    2     3
  zeropage,X    SBC oper,X    F5    2     4
  absolute      SBC oper      ED    3     4
  absolute,X    SBC oper,X    FD    3     4*
  absolute,Y    SBC oper,Y    F9    3     4*
  (indirect,X)  SBC (oper,X)  E1    2     6
  (indirect),Y  SBC (oper),Y  F1    2     5*
   */

  CPU.prototype.SBC = function(stepInfo) {
    var H4b, operand;
    operand = -stepInfo.operand;
    this.AC = this.accumulate(operand, this.AC, this.C);
    console.log('@AC', this.AC);
    this.C = this.AC > 0xFF ? 1 : 0;
    this.setZN(this.AC);
    H4b = this.AC / 0x10;
    this.V = H4b >= -8 & H4b <= 7 ? 0 : 1;
    if (this.V === 1) {
      console.warn('High 4 bit', H4b.toString(16), 'is not in range(-8~7). Overflow!!');
      console.log('@H4b is', H4b.toString(16));
    }
    return this.AC = this.AC & 0xFF;
  };


  /*
  
  SEC  Set Carry Flag
  
  1 -> C                           N Z C I D V
                                   - - 1 - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEC           38    1     2
   */

  CPU.prototype.SEC = function() {
    return this.C = 1;
  };


  /*
  SED  Set Decimal Flag
  
  1 -> D                           N Z C I D V
                                   - - - - 1 -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SED           F8    1     2
   */

  CPU.prototype.SED = function() {
    return this.D = 1;
  };


  /*
  
  SEI  Set Interrupt Disable Status
  
  1 -> I                           N Z C I D V
                                - - - 1 - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       SEI           78    1     2
   */

  CPU.prototype.SEI = function(stepInfo) {
    return this.I = 1;
  };


  /*
  
  STA  Store Accumulator in Memory
  
  A -> M                           N Z C I D V
                                   - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STA oper      85    2     3
  zeropage,X    STA oper,X    95    2     4
  absolute      STA oper      8D    3     4
  absolute,X    STA oper,X    9D    3     5
  absolute,Y    STA oper,Y    99    3     5
  (indirect,X)  STA (oper,X)  81    2     6
  (indirect),Y  STA (oper),Y  91    2     6
   */

  CPU.prototype.STA = function(stepInfo) {
    return this.ram[stepInfo.addressMode.address] = this.AC;
  };


  /*
  
  STX  Store Index X in Memory
  
  X -> M                           N Z C I D V
                                - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STX oper      86    2     3
  zeropage,Y    STX oper,Y    96    2     4
  absolute      STX oper      8E    3     4
   */

  CPU.prototype.STX = function(stepInfo) {
    return this.ram[stepInfo.addressMode.address] = this.XR;
  };


  /*
  
  STY  Sore Index Y in Memory
  
  Y -> M                           N Z C I D V
                                   - - - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  zeropage      STY oper      84    2     3
  zeropage,X    STY oper,X    94    2     4
  absolute      STY oper      8C    3     4
   */

  CPU.prototype.STY = function(stepInfo) {
    return this.ram[stepInfo.addressMode.address] = this.YR;
  };


  /*
  
  TAX  Transfer Accumulator to Index X
  
  A -> X                           N Z C I D V
                                   + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAX           AA    1     2
   */

  CPU.prototype.TAX = function(stepInfo) {
    this.XR = this.AC;
    return this.setZN(this.XR);
  };


  /*
  
  TAY  Transfer Accumulator to Index Y
  
  A -> Y                           N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TAY           A8    1     2
   */

  CPU.prototype.TAY = function(stepInfo) {
    this.YR = this.AC;
    return this.setZN(this.YR);
  };


  /*
  
  TSX  Transfer Stack Pointer to Index X
  
  SP -> X                          N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TSX           BA    1     2
   */

  CPU.prototype.TSX = function(stepInfo) {
    this.XR = this.SP;
    return this.setZN(this.XR);
  };


  /*
  
  TXA  Transfer Index X to Accumulator
  
  X -> A                           N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXA           8A    1     2
   */

  CPU.prototype.TXA = function(stepInfo) {
    this.AC = this.R;
    return this.setZN(this.AC);
  };


  /*
  
  TXS  Transfer Index X to Stack Register
  
  X -> SP                          N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TXS           9A    1     2
   */

  CPU.prototype.TXS = function(stepInfo) {
    this.SP = this.XR;
    return this.setZN(this.SP);
  };


  /*
  
  TYA  Transfer Index Y to Accumulator
  
  Y -> A                           N Z C I D V
                                + + - - - -
  
  addressing    assembler    opc  bytes  cyles
  --------------------------------------------
  implied       TYA           98    1     2
   */

  CPU.prototype.TYA = function(stepInfo) {
    this.AC = this.YR;
    return this.setZN(this.AC);
  };

  CPU.prototype.OPRCODES = {
    0x00: {
      instruction: CPU.prototype.BRK,
      text: 'BRK',
      addressMode: CPU.prototype.implied,
      desc: 'BRK implied'
    },
    0x01: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.indirect,
      desc: 'ORA indirect'
    },
    0x05: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.zeropage,
      desc: 'ORA zeropage'
    },
    0x06: {
      instruction: CPU.prototype.ASL,
      text: 'ASL',
      addressMode: CPU.prototype.zeropage,
      desc: 'ASL zeropage'
    },
    0x08: {
      instruction: CPU.prototype.PHP,
      text: 'PHP',
      addressMode: CPU.prototype.implied,
      desc: 'PHP implied'
    },
    0x09: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.immediate,
      desc: 'ORA immediate'
    },
    0x0A: {
      instruction: CPU.prototype.ASL,
      text: 'ASL',
      addressMode: CPU.prototype.accumulator,
      desc: 'ASL accumulator'
    },
    0x0D: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.absolute,
      desc: 'ORA absolute'
    },
    0x0E: {
      instruction: CPU.prototype.ASL,
      text: 'ASL',
      addressMode: CPU.prototype.absolute,
      desc: 'ASL absolute'
    },
    0x10: {
      instruction: CPU.prototype.BPL,
      text: 'BPL',
      addressMode: CPU.prototype.relative,
      desc: 'BPL relative'
    },
    0x11: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.indirectY,
      desc: 'ORA indirectY'
    },
    0x15: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.indirectX,
      desc: 'ORA indirectX'
    },
    0x16: {
      instruction: CPU.prototype.ASL,
      text: 'ASL',
      addressMode: CPU.prototype.indirectX,
      desc: 'ASL indirectX'
    },
    0x18: {
      instruction: CPU.prototype.CLC,
      text: 'CLC',
      addressMode: CPU.prototype.implied,
      desc: 'CLC implied'
    },
    0x19: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.absoluteY,
      desc: 'ORA absoluteY'
    },
    0x1D: {
      instruction: CPU.prototype.ORA,
      text: 'ORA',
      addressMode: CPU.prototype.absoluteX,
      desc: 'ORA absoluteX'
    },
    0x1E: {
      instruction: CPU.prototype.ASL,
      text: 'ASL',
      addressMode: CPU.prototype.absoluteX,
      desc: 'ASL absoluteX'
    },
    0x20: {
      instruction: CPU.prototype.JSR,
      text: 'JSR',
      addressMode: CPU.prototype.absolute,
      desc: 'JSR absolute'
    },
    0x21: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.indirect,
      desc: 'AND indirect'
    },
    0x24: {
      instruction: CPU.prototype.BIT,
      text: 'BIT',
      addressMode: CPU.prototype.zeropage,
      desc: 'BIT zeropage'
    },
    0x25: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.zeropage,
      desc: 'AND zeropage'
    },
    0x26: {
      instruction: CPU.prototype.ROL,
      text: 'ROL',
      addressMode: CPU.prototype.zeropage,
      desc: 'ROL zeropage'
    },
    0x28: {
      instruction: CPU.prototype.PLP,
      text: 'PLP',
      addressMode: CPU.prototype.implied,
      desc: 'PLP implied'
    },
    0x29: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.immediate,
      desc: 'AND immediate'
    },
    0x2A: {
      instruction: CPU.prototype.ROL,
      text: 'ROL',
      addressMode: CPU.prototype.accumulator,
      desc: 'ROL accumulator'
    },
    0x2C: {
      instruction: CPU.prototype.BIT,
      text: 'BIT',
      addressMode: CPU.prototype.absolute,
      desc: 'BIT absolute'
    },
    0x2D: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.absolute,
      desc: 'AND absolute'
    },
    0x2E: {
      instruction: CPU.prototype.ROL,
      text: 'ROL',
      addressMode: CPU.prototype.absolute,
      desc: 'ROL absolute'
    },
    0x30: {
      instruction: CPU.prototype.BMI,
      text: 'BMI',
      addressMode: CPU.prototype.relative,
      desc: 'BMI relative'
    },
    0x31: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.indirectY,
      desc: 'AND indirectY'
    },
    0x35: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.indirectX,
      desc: 'AND indirectX'
    },
    0x36: {
      instruction: CPU.prototype.ROL,
      text: 'ROL',
      addressMode: CPU.prototype.indirectX,
      desc: 'ROL indirectX'
    },
    0x38: {
      instruction: CPU.prototype.SEC,
      text: 'SEC',
      addressMode: CPU.prototype.implied,
      desc: 'SEC implied'
    },
    0x39: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.absoluteY,
      desc: 'AND absoluteY'
    },
    0x3C: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.absoluteX,
      desc: 'NOP absoluteX'
    },
    0x3D: {
      instruction: CPU.prototype.AND,
      text: 'AND',
      addressMode: CPU.prototype.absoluteX,
      desc: 'AND absoluteX'
    },
    0x3E: {
      instruction: CPU.prototype.ROL,
      text: 'ROL',
      addressMode: CPU.prototype.absoluteX,
      desc: 'ROL absoluteX'
    },
    0x40: {
      instruction: CPU.prototype.RTI,
      text: 'RTI',
      addressMode: CPU.prototype.implied,
      desc: 'RTI implied'
    },
    0x41: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.indirect,
      desc: 'EOR indirect'
    },
    0x45: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.zeropage,
      desc: 'EOR zeropage'
    },
    0x46: {
      instruction: CPU.prototype.LSR,
      text: 'LSR',
      addressMode: CPU.prototype.zeropage,
      desc: 'LSR zeropage'
    },
    0x48: {
      instruction: CPU.prototype.PHA,
      text: 'PHA',
      addressMode: CPU.prototype.implied,
      desc: 'PHA implied'
    },
    0x49: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.immediate,
      desc: 'EOR immediate'
    },
    0x4A: {
      instruction: CPU.prototype.LSR,
      text: 'LSR',
      addressMode: CPU.prototype.accumulator,
      desc: 'LSR accumulator'
    },
    0x4C: {
      instruction: CPU.prototype.JMP,
      text: 'JMP',
      addressMode: CPU.prototype.absolute,
      desc: 'JMP absolute'
    },
    0x4D: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.absolute,
      desc: 'EOR absolute'
    },
    0x4E: {
      instruction: CPU.prototype.LSR,
      text: 'LSR',
      addressMode: CPU.prototype.absolute,
      desc: 'LSR absolute'
    },
    0x50: {
      instruction: CPU.prototype.BVC,
      text: 'BVC',
      addressMode: CPU.prototype.relative,
      desc: 'BVC relative'
    },
    0x51: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.indirectY,
      desc: 'EOR indirectY'
    },
    0x55: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.indirectX,
      desc: 'EOR indirectX'
    },
    0x56: {
      instruction: CPU.prototype.LSR,
      text: 'LSR',
      addressMode: CPU.prototype.indirectX,
      desc: 'LSR indirectX'
    },
    0x58: {
      instruction: CPU.prototype.CLI,
      text: 'CLI',
      addressMode: CPU.prototype.implied,
      desc: 'CLI implied'
    },
    0x59: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.absoluteY,
      desc: 'EOR absoluteY'
    },
    0x5D: {
      instruction: CPU.prototype.EOR,
      text: 'EOR',
      addressMode: CPU.prototype.absoluteX,
      desc: 'EOR absoluteX'
    },
    0x5E: {
      instruction: CPU.prototype.LSR,
      text: 'LSR',
      addressMode: CPU.prototype.absoluteX,
      desc: 'LSR absoluteX'
    },
    0x60: {
      instruction: CPU.prototype.RTS,
      text: 'RTS',
      addressMode: CPU.prototype.implied,
      desc: 'RTS implied'
    },
    0x61: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.indirect,
      desc: 'ADC indirect'
    },
    0x65: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.zeropage,
      desc: 'ADC zeropage'
    },
    0x66: {
      instruction: CPU.prototype.ROR,
      text: 'ROR',
      addressMode: CPU.prototype.zeropage,
      desc: 'ROR zeropage'
    },
    0x68: {
      instruction: CPU.prototype.PLA,
      text: 'PLA',
      addressMode: CPU.prototype.implied,
      desc: 'PLA implied'
    },
    0x69: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.immediate,
      desc: 'ADC immediate'
    },
    0x6A: {
      instruction: CPU.prototype.ROR,
      text: 'ROR',
      addressMode: CPU.prototype.accumulator,
      desc: 'ROR accumulator'
    },
    0x6C: {
      instruction: CPU.prototype.JMP,
      text: 'JMP',
      addressMode: CPU.prototype.indirect,
      desc: 'JMP indirect'
    },
    0x6D: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.absolute,
      desc: 'ADC absolute'
    },
    0x6E: {
      instruction: CPU.prototype.ROR,
      text: 'ROR',
      addressMode: CPU.prototype.absolute,
      desc: 'ROR absolute'
    },
    0x70: {
      instruction: CPU.prototype.BVS,
      text: 'BVS',
      addressMode: CPU.prototype.relative,
      desc: 'BVS relative'
    },
    0x71: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.indirectY,
      desc: 'ADC indirectY'
    },
    0x75: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.indirectX,
      desc: 'ADC indirectX'
    },
    0x76: {
      instruction: CPU.prototype.ROR,
      text: 'ROR',
      addressMode: CPU.prototype.indirectX,
      desc: 'ROR indirectX'
    },
    0x78: {
      instruction: CPU.prototype.SEI,
      text: 'SEI',
      addressMode: CPU.prototype.implied,
      desc: 'SEI implied'
    },
    0x79: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.absoluteY,
      desc: 'ADC absoluteY'
    },
    0x7D: {
      instruction: CPU.prototype.ADC,
      text: 'ADC',
      addressMode: CPU.prototype.absoluteX,
      desc: 'ADC absoluteX'
    },
    0x7E: {
      instruction: CPU.prototype.ROR,
      text: 'ROR',
      addressMode: CPU.prototype.absoluteX,
      desc: 'ROR absoluteX'
    },
    0x81: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.indirect,
      desc: 'STA indirect'
    },
    0x82: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.immediate,
      desc: 'NOP immediate'
    },
    0x84: {
      instruction: CPU.prototype.STY,
      text: 'STY',
      addressMode: CPU.prototype.zeropage,
      desc: 'STY zeropage'
    },
    0x85: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.zeropage,
      desc: 'STA zeropage'
    },
    0x86: {
      instruction: CPU.prototype.STX,
      text: 'STX',
      addressMode: CPU.prototype.zeropage,
      desc: 'STX zeropage'
    },
    0x88: {
      instruction: CPU.prototype.DEY,
      text: 'DEY',
      addressMode: CPU.prototype.implied,
      desc: 'DEY implied'
    },
    0x8A: {
      instruction: CPU.prototype.TXA,
      text: 'TXA',
      addressMode: CPU.prototype.implied,
      desc: 'TXA implied'
    },
    0x8C: {
      instruction: CPU.prototype.STY,
      text: 'STY',
      addressMode: CPU.prototype.absolute,
      desc: 'STY absolute'
    },
    0x8D: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.absolute,
      desc: 'STA absolute'
    },
    0x8E: {
      instruction: CPU.prototype.STX,
      text: 'STX',
      addressMode: CPU.prototype.absolute,
      desc: 'STX absolute'
    },
    0x90: {
      instruction: CPU.prototype.BCC,
      text: 'BCC',
      addressMode: CPU.prototype.relative,
      desc: 'BCC relative'
    },
    0x91: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.indirectY,
      desc: 'STA indirectY'
    },
    0x94: {
      instruction: CPU.prototype.STY,
      text: 'STY',
      addressMode: CPU.prototype.indirectX,
      desc: 'STY indirectX'
    },
    0x95: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.indirectX,
      desc: 'STA indirectX'
    },
    0x96: {
      instruction: CPU.prototype.STX,
      text: 'STX',
      addressMode: CPU.prototype.zeropageY,
      desc: 'STX zeropageY'
    },
    0x98: {
      instruction: CPU.prototype.TYA,
      text: 'TYA',
      addressMode: CPU.prototype.implied,
      desc: 'TYA implied'
    },
    0x99: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.absoluteY,
      desc: 'STA absoluteY'
    },
    0x9A: {
      instruction: CPU.prototype.TXS,
      text: 'TXS',
      addressMode: CPU.prototype.implied,
      desc: 'TXS implied'
    },
    0x9D: {
      instruction: CPU.prototype.STA,
      text: 'STA',
      addressMode: CPU.prototype.absoluteX,
      desc: 'STA absoluteX'
    },
    0xA0: {
      instruction: CPU.prototype.LDY,
      text: 'LDY',
      addressMode: CPU.prototype.immediate,
      desc: 'LDY immediate'
    },
    0xA1: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.indirect,
      desc: 'LDA indirect'
    },
    0xA2: {
      instruction: CPU.prototype.LDX,
      text: 'LDX',
      addressMode: CPU.prototype.immediate,
      desc: 'LDX immediate'
    },
    0xA4: {
      instruction: CPU.prototype.LDY,
      text: 'LDY',
      addressMode: CPU.prototype.zeropage,
      desc: 'LDY zeropage'
    },
    0xA5: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.zeropage,
      desc: 'LDA zeropage'
    },
    0xA6: {
      instruction: CPU.prototype.LDX,
      text: 'LDX',
      addressMode: CPU.prototype.zeropage,
      desc: 'LDX zeropage'
    },
    0xA8: {
      instruction: CPU.prototype.TAY,
      text: 'TAY',
      addressMode: CPU.prototype.implied,
      desc: 'TAY implied'
    },
    0xA9: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.immediate,
      desc: 'LDA immediate'
    },
    0xAA: {
      instruction: CPU.prototype.TAX,
      text: 'TAX',
      addressMode: CPU.prototype.implied,
      desc: 'TAX implied'
    },
    0xAC: {
      instruction: CPU.prototype.LDY,
      text: 'LDY',
      addressMode: CPU.prototype.absolute,
      desc: 'LDY absolute'
    },
    0xAD: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.absolute,
      desc: 'LDA absolute'
    },
    0xAE: {
      instruction: CPU.prototype.LDX,
      text: 'LDX',
      addressMode: CPU.prototype.absolute,
      desc: 'LDX absolute'
    },
    0xB0: {
      instruction: CPU.prototype.BCS,
      text: 'BCS',
      addressMode: CPU.prototype.relative,
      desc: 'BCS relative'
    },
    0xB1: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.indirectY,
      desc: 'LDA indirectY'
    },
    0xB4: {
      instruction: CPU.prototype.LDY,
      text: 'LDY',
      addressMode: CPU.prototype.indirectX,
      desc: 'LDY indirectX'
    },
    0xB5: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.indirectX,
      desc: 'LDA indirectX'
    },
    0xB6: {
      instruction: CPU.prototype.LDX,
      text: 'LDX',
      addressMode: CPU.prototype.zeropageY,
      desc: 'LDX zeropageY'
    },
    0xB8: {
      instruction: CPU.prototype.CLV,
      text: 'CLV',
      addressMode: CPU.prototype.implied,
      desc: 'CLV implied'
    },
    0xB9: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.absoluteY,
      desc: 'LDA absoluteY'
    },
    0xBA: {
      instruction: CPU.prototype.TSX,
      text: 'TSX',
      addressMode: CPU.prototype.implied,
      desc: 'TSX implied'
    },
    0xBC: {
      instruction: CPU.prototype.LDY,
      text: 'LDY',
      addressMode: CPU.prototype.absoluteX,
      desc: 'LDY absoluteX'
    },
    0xBD: {
      instruction: CPU.prototype.LDA,
      text: 'LDA',
      addressMode: CPU.prototype.absoluteX,
      desc: 'LDA absoluteX'
    },
    0xBE: {
      instruction: CPU.prototype.LDX,
      text: 'LDX',
      addressMode: CPU.prototype.absoluteY,
      desc: 'LDX absoluteY'
    },
    0xC0: {
      instruction: CPU.prototype.CPY,
      text: 'CPY',
      addressMode: CPU.prototype.immediate,
      desc: 'CPY immediate'
    },
    0xC1: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.indirect,
      desc: 'CMP indirect'
    },
    0xC2: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.immediate,
      desc: 'NOP immediate'
    },
    0xC4: {
      instruction: CPU.prototype.CPY,
      text: 'CPY',
      addressMode: CPU.prototype.zeropage,
      desc: 'CPY zeropage'
    },
    0xC5: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.zeropage,
      desc: 'CMP zeropage'
    },
    0xC6: {
      instruction: CPU.prototype.DEC,
      text: 'DEC',
      addressMode: CPU.prototype.zeropage,
      desc: 'DEC zeropage'
    },
    0xC8: {
      instruction: CPU.prototype.INY,
      text: 'INY',
      addressMode: CPU.prototype.implied,
      desc: 'INY implied'
    },
    0xC9: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.immediate,
      desc: 'CMP immediate'
    },
    0xCA: {
      instruction: CPU.prototype.DEX,
      text: 'DEX',
      addressMode: CPU.prototype.implied,
      desc: 'DEX implied'
    },
    0xCC: {
      instruction: CPU.prototype.CPY,
      text: 'CPY',
      addressMode: CPU.prototype.absolute,
      desc: 'CPY absolute'
    },
    0xCD: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.absolute,
      desc: 'CMP absolute'
    },
    0xCE: {
      instruction: CPU.prototype.DEC,
      text: 'DEC',
      addressMode: CPU.prototype.absolute,
      desc: 'DEC absolute'
    },
    0xD0: {
      instruction: CPU.prototype.BNE,
      text: 'BNE',
      addressMode: CPU.prototype.relative,
      desc: 'BNE relative'
    },
    0xD1: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.indirectY,
      desc: 'CMP indirectY'
    },
    0xD5: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.indirectX,
      desc: 'CMP indirectX'
    },
    0xD6: {
      instruction: CPU.prototype.DEC,
      text: 'DEC',
      addressMode: CPU.prototype.indirectX,
      desc: 'DEC indirectX'
    },
    0xD8: {
      instruction: CPU.prototype.CLD,
      text: 'CLD',
      addressMode: CPU.prototype.implied,
      desc: 'CLD implied'
    },
    0xD9: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.absoluteY,
      desc: 'CMP absoluteY'
    },
    0xDD: {
      instruction: CPU.prototype.CMP,
      text: 'CMP',
      addressMode: CPU.prototype.absoluteX,
      desc: 'CMP absoluteX'
    },
    0xDE: {
      instruction: CPU.prototype.DEC,
      text: 'DEC',
      addressMode: CPU.prototype.absoluteX,
      desc: 'DEC absoluteX'
    },
    0xE0: {
      instruction: CPU.prototype.CPX,
      text: 'CPX',
      addressMode: CPU.prototype.immediate,
      desc: 'CPX immediate'
    },
    0xE1: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.indirect,
      desc: 'SBC indirect'
    },
    0xE2: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.immediate,
      desc: 'NOP immediate'
    },
    0xE4: {
      instruction: CPU.prototype.CPX,
      text: 'CPX',
      addressMode: CPU.prototype.zeropage,
      desc: 'CPX zeropage'
    },
    0xE5: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.zeropage,
      desc: 'SBC zeropage'
    },
    0xE6: {
      instruction: CPU.prototype.INC,
      text: 'INC',
      addressMode: CPU.prototype.zeropage,
      desc: 'INC zeropage'
    },
    0xE8: {
      instruction: CPU.prototype.INX,
      text: 'INX',
      addressMode: CPU.prototype.implied,
      desc: 'INX implied'
    },
    0xE9: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.immediate,
      desc: 'SBC immediate'
    },
    0xEA: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.implied,
      desc: 'NOP implied'
    },
    0xEC: {
      instruction: CPU.prototype.CPX,
      text: 'CPX',
      addressMode: CPU.prototype.absolute,
      desc: 'CPX absolute'
    },
    0xED: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.absolute,
      desc: 'SBC absolute'
    },
    0xEE: {
      instruction: CPU.prototype.INC,
      text: 'INC',
      addressMode: CPU.prototype.absolute,
      desc: 'INC absolute'
    },
    0xF0: {
      instruction: CPU.prototype.BEQ,
      text: 'BEQ',
      addressMode: CPU.prototype.relative,
      desc: 'BEQ relative'
    },
    0xF1: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.indirectY,
      desc: 'SBC indirectY'
    },
    0xF4: {
      instruction: CPU.prototype.NOP,
      text: 'NOP',
      addressMode: CPU.prototype.zeropageX,
      desc: 'NOP zeropageX'
    },
    0xF5: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.indirectX,
      desc: 'SBC indirectX'
    },
    0xF6: {
      instruction: CPU.prototype.INC,
      text: 'INC',
      addressMode: CPU.prototype.indirectX,
      desc: 'INC indirectX'
    },
    0xF8: {
      instruction: CPU.prototype.SED,
      text: 'SED',
      addressMode: CPU.prototype.implied,
      desc: 'SED implied'
    },
    0xF9: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.absoluteY,
      desc: 'SBC absoluteY'
    },
    0xFD: {
      instruction: CPU.prototype.SBC,
      text: 'SBC',
      addressMode: CPU.prototype.absoluteX,
      desc: 'SBC absoluteX'
    },
    0xFE: {
      instruction: CPU.prototype.INC,
      text: 'INC',
      addressMode: CPU.prototype.absoluteX,
      desc: 'INC absoluteX'
    }
  };

  return CPU;

})();

exports.CPU = CPU;

exports.OPRCODES = CPU.prototype.OPRCODES;

//# sourceMappingURL=2a03.js.map
