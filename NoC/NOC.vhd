library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.std_logic_unsigned.all;
use work.PhoenixPackage.all;
use work.HammingPack16.all;
use ieee.std_logic_arith.CONV_STD_LOGIC_VECTOR;

entity NOC is
port(
	clock         : in  regNrot;
	reset         : in  std_logic;
	clock_rxLocal : in  regNrot;
	rxLocal       : in  regNrot;
	data_inLocal_flit  : in  arrayNrot_regflit;
	credit_oLocal : out regNrot;
	clock_txLocal : out regNrot;
	txLocal       : out regNrot;
	data_outLocal_flit : out arrayNrot_regflit;
	credit_iLocal : in  regNrot);
end NOC;

architecture NOC of NOC is

	-- novos sinais--
	signal data_inLocal: arrayNrot_regphit;
	signal data_outLocal: arrayNrot_regphit;
	--
	signal clock_rxN0000, clock_rxN0100, clock_rxN0200, clock_rxN0300, clock_rxN0400 : regNport;
	signal rxN0000, rxN0100, rxN0200, rxN0300, rxN0400 : regNport;
	signal data_inN0000, data_inN0100, data_inN0200, data_inN0300, data_inN0400 : arrayNport_regphit;
	signal credit_oN0000, credit_oN0100, credit_oN0200, credit_oN0300, credit_oN0400 : regNport;
	signal clock_txN0000, clock_txN0100, clock_txN0200, clock_txN0300, clock_txN0400 : regNport;
	signal txN0000, txN0100, txN0200, txN0300, txN0400 : regNport;
	signal data_outN0000, data_outN0100, data_outN0200, data_outN0300, data_outN0400 : arrayNport_regphit;
	signal credit_iN0000, credit_iN0100, credit_iN0200, credit_iN0300, credit_iN0400 : regNport;
	signal testLink_iN0000, testLink_iN0100, testLink_iN0200, testLink_iN0300, testLink_iN0400 : regNport;
	signal testLink_oN0000, testLink_oN0100, testLink_oN0200, testLink_oN0300, testLink_oN0400 : regNport;
	signal retransmission_iN0000, retransmission_iN0100, retransmission_iN0200, retransmission_iN0300, retransmission_iN0400 : regNport;
	signal retransmission_oN0000, retransmission_oN0100, retransmission_oN0200, retransmission_oN0300, retransmission_oN0400 : regNport;

	signal clock_rxN0001, clock_rxN0101, clock_rxN0201, clock_rxN0301, clock_rxN0401 : regNport;
	signal rxN0001, rxN0101, rxN0201, rxN0301, rxN0401 : regNport;
	signal data_inN0001, data_inN0101, data_inN0201, data_inN0301, data_inN0401 : arrayNport_regphit;
	signal credit_oN0001, credit_oN0101, credit_oN0201, credit_oN0301, credit_oN0401 : regNport;
	signal clock_txN0001, clock_txN0101, clock_txN0201, clock_txN0301, clock_txN0401 : regNport;
	signal txN0001, txN0101, txN0201, txN0301, txN0401 : regNport;
	signal data_outN0001, data_outN0101, data_outN0201, data_outN0301, data_outN0401 : arrayNport_regphit;
	signal credit_iN0001, credit_iN0101, credit_iN0201, credit_iN0301, credit_iN0401 : regNport;
	signal testLink_iN0001, testLink_iN0101, testLink_iN0201, testLink_iN0301, testLink_iN0401 : regNport;
	signal testLink_oN0001, testLink_oN0101, testLink_oN0201, testLink_oN0301, testLink_oN0401 : regNport;
	signal retransmission_iN0001, retransmission_iN0101, retransmission_iN0201, retransmission_iN0301, retransmission_iN0401 : regNport;
	signal retransmission_oN0001, retransmission_oN0101, retransmission_oN0201, retransmission_oN0301, retransmission_oN0401 : regNport;

	signal clock_rxN0002, clock_rxN0102, clock_rxN0202, clock_rxN0302, clock_rxN0402 : regNport;
	signal rxN0002, rxN0102, rxN0202, rxN0302, rxN0402 : regNport;
	signal data_inN0002, data_inN0102, data_inN0202, data_inN0302, data_inN0402 : arrayNport_regphit;
	signal credit_oN0002, credit_oN0102, credit_oN0202, credit_oN0302, credit_oN0402 : regNport;
	signal clock_txN0002, clock_txN0102, clock_txN0202, clock_txN0302, clock_txN0402 : regNport;
	signal txN0002, txN0102, txN0202, txN0302, txN0402 : regNport;
	signal data_outN0002, data_outN0102, data_outN0202, data_outN0302, data_outN0402 : arrayNport_regphit;
	signal credit_iN0002, credit_iN0102, credit_iN0202, credit_iN0302, credit_iN0402 : regNport;
	signal testLink_iN0002, testLink_iN0102, testLink_iN0202, testLink_iN0302, testLink_iN0402 : regNport;
	signal testLink_oN0002, testLink_oN0102, testLink_oN0202, testLink_oN0302, testLink_oN0402 : regNport;
	signal retransmission_iN0002, retransmission_iN0102, retransmission_iN0202, retransmission_iN0302, retransmission_iN0402 : regNport;
	signal retransmission_oN0002, retransmission_oN0102, retransmission_oN0202, retransmission_oN0302, retransmission_oN0402 : regNport;

	signal clock_rxN0003, clock_rxN0103, clock_rxN0203, clock_rxN0303, clock_rxN0403 : regNport;
	signal rxN0003, rxN0103, rxN0203, rxN0303, rxN0403 : regNport;
	signal data_inN0003, data_inN0103, data_inN0203, data_inN0303, data_inN0403 : arrayNport_regphit;
	signal credit_oN0003, credit_oN0103, credit_oN0203, credit_oN0303, credit_oN0403 : regNport;
	signal clock_txN0003, clock_txN0103, clock_txN0203, clock_txN0303, clock_txN0403 : regNport;
	signal txN0003, txN0103, txN0203, txN0303, txN0403 : regNport;
	signal data_outN0003, data_outN0103, data_outN0203, data_outN0303, data_outN0403 : arrayNport_regphit;
	signal credit_iN0003, credit_iN0103, credit_iN0203, credit_iN0303, credit_iN0403 : regNport;
	signal testLink_iN0003, testLink_iN0103, testLink_iN0203, testLink_iN0303, testLink_iN0403 : regNport;
	signal testLink_oN0003, testLink_oN0103, testLink_oN0203, testLink_oN0303, testLink_oN0403 : regNport;
	signal retransmission_iN0003, retransmission_iN0103, retransmission_iN0203, retransmission_iN0303, retransmission_iN0403 : regNport;
	signal retransmission_oN0003, retransmission_oN0103, retransmission_oN0203, retransmission_oN0303, retransmission_oN0403 : regNport;

	signal clock_rxN0004, clock_rxN0104, clock_rxN0204, clock_rxN0304, clock_rxN0404 : regNport;
	signal rxN0004, rxN0104, rxN0204, rxN0304, rxN0404 : regNport;
	signal data_inN0004, data_inN0104, data_inN0204, data_inN0304, data_inN0404 : arrayNport_regphit;
	signal credit_oN0004, credit_oN0104, credit_oN0204, credit_oN0304, credit_oN0404 : regNport;
	signal clock_txN0004, clock_txN0104, clock_txN0204, clock_txN0304, clock_txN0404 : regNport;
	signal txN0004, txN0104, txN0204, txN0304, txN0404 : regNport;
	signal data_outN0004, data_outN0104, data_outN0204, data_outN0304, data_outN0404 : arrayNport_regphit;
	signal credit_iN0004, credit_iN0104, credit_iN0204, credit_iN0304, credit_iN0404 : regNport;
	signal testLink_iN0004, testLink_iN0104, testLink_iN0204, testLink_iN0304, testLink_iN0404 : regNport;
	signal testLink_oN0004, testLink_oN0104, testLink_oN0204, testLink_oN0304, testLink_oN0404 : regNport;
	signal retransmission_iN0004, retransmission_iN0104, retransmission_iN0204, retransmission_iN0304, retransmission_iN0404 : regNport;
	signal retransmission_oN0004, retransmission_oN0104, retransmission_oN0204, retransmission_oN0304, retransmission_oN0404 : regNport;
begin

		fillLocalFlits: for i in 0 to NROT-1 generate
		begin
			data_inLocal(i) <= data_inLocal_flit(i) & CONV_STD_LOGIC_VECTOR(0,TAM_HAMM);
			data_outLocal_flit(i) <= data_outLocal(i)(TAM_PHIT-1 downto TAM_HAMM);
		end generate;

	Router0000 : Entity work.RouterCC
	generic map( address => ADDRESSN0000 )
	port map(
		clock    => clock(N0000),
		reset    => reset,
		clock_rx => clock_rxN0000,
		rx       => rxN0000,
		data_in  => data_inN0000,
		credit_o => credit_oN0000,
		clock_tx => clock_txN0000,
		tx       => txN0000,
		data_out => data_outN0000,
		credit_i => credit_iN0000,
		testLink_i => testLink_iN0000,
		testLink_o => testLink_oN0000,
		retransmission_i => retransmission_iN0000,
		retransmission_o => retransmission_oN0000);

	Router0100 : Entity work.RouterCC
	generic map( address => ADDRESSN0100 )
	port map(
		clock    => clock(N0100),
		reset    => reset,
		clock_rx => clock_rxN0100,
		rx       => rxN0100,
		data_in  => data_inN0100,
		credit_o => credit_oN0100,
		clock_tx => clock_txN0100,
		tx       => txN0100,
		data_out => data_outN0100,
		credit_i => credit_iN0100,
		testLink_i => testLink_iN0100,
		testLink_o => testLink_oN0100,
		retransmission_i => retransmission_iN0100,
		retransmission_o => retransmission_oN0100);

	Router0200 : Entity work.RouterCC
	generic map( address => ADDRESSN0200 )
	port map(
		clock    => clock(N0200),
		reset    => reset,
		clock_rx => clock_rxN0200,
		rx       => rxN0200,
		data_in  => data_inN0200,
		credit_o => credit_oN0200,
		clock_tx => clock_txN0200,
		tx       => txN0200,
		data_out => data_outN0200,
		credit_i => credit_iN0200,
		testLink_i => testLink_iN0200,
		testLink_o => testLink_oN0200,
		retransmission_i => retransmission_iN0200,
		retransmission_o => retransmission_oN0200);

	Router0300 : Entity work.RouterCC
	generic map( address => ADDRESSN0300 )
	port map(
		clock    => clock(N0300),
		reset    => reset,
		clock_rx => clock_rxN0300,
		rx       => rxN0300,
		data_in  => data_inN0300,
		credit_o => credit_oN0300,
		clock_tx => clock_txN0300,
		tx       => txN0300,
		data_out => data_outN0300,
		credit_i => credit_iN0300,
		testLink_i => testLink_iN0300,
		testLink_o => testLink_oN0300,
		retransmission_i => retransmission_iN0300,
		retransmission_o => retransmission_oN0300);

	Router0400 : Entity work.RouterCC
	generic map( address => ADDRESSN0400 )
	port map(
		clock    => clock(N0400),
		reset    => reset,
		clock_rx => clock_rxN0400,
		rx       => rxN0400,
		data_in  => data_inN0400,
		credit_o => credit_oN0400,
		clock_tx => clock_txN0400,
		tx       => txN0400,
		data_out => data_outN0400,
		credit_i => credit_iN0400,
		testLink_i => testLink_iN0400,
		testLink_o => testLink_oN0400,
		retransmission_i => retransmission_iN0400,
		retransmission_o => retransmission_oN0400);

	Router0001 : Entity work.RouterCC
	generic map( address => ADDRESSN0001 )
	port map(
		clock    => clock(N0001),
		reset    => reset,
		clock_rx => clock_rxN0001,
		rx       => rxN0001,
		data_in  => data_inN0001,
		credit_o => credit_oN0001,
		clock_tx => clock_txN0001,
		tx       => txN0001,
		data_out => data_outN0001,
		credit_i => credit_iN0001,
		testLink_i => testLink_iN0001,
		testLink_o => testLink_oN0001,
		retransmission_i => retransmission_iN0001,
		retransmission_o => retransmission_oN0001);

	Router0101 : Entity work.RouterCC
	generic map( address => ADDRESSN0101 )
	port map(
		clock    => clock(N0101),
		reset    => reset,
		clock_rx => clock_rxN0101,
		rx       => rxN0101,
		data_in  => data_inN0101,
		credit_o => credit_oN0101,
		clock_tx => clock_txN0101,
		tx       => txN0101,
		data_out => data_outN0101,
		credit_i => credit_iN0101,
		testLink_i => testLink_iN0101,
		testLink_o => testLink_oN0101,
		retransmission_i => retransmission_iN0101,
		retransmission_o => retransmission_oN0101);

	Router0201 : Entity work.RouterCC
	generic map( address => ADDRESSN0201 )
	port map(
		clock    => clock(N0201),
		reset    => reset,
		clock_rx => clock_rxN0201,
		rx       => rxN0201,
		data_in  => data_inN0201,
		credit_o => credit_oN0201,
		clock_tx => clock_txN0201,
		tx       => txN0201,
		data_out => data_outN0201,
		credit_i => credit_iN0201,
		testLink_i => testLink_iN0201,
		testLink_o => testLink_oN0201,
		retransmission_i => retransmission_iN0201,
		retransmission_o => retransmission_oN0201);

	Router0301 : Entity work.RouterCC
	generic map( address => ADDRESSN0301 )
	port map(
		clock    => clock(N0301),
		reset    => reset,
		clock_rx => clock_rxN0301,
		rx       => rxN0301,
		data_in  => data_inN0301,
		credit_o => credit_oN0301,
		clock_tx => clock_txN0301,
		tx       => txN0301,
		data_out => data_outN0301,
		credit_i => credit_iN0301,
		testLink_i => testLink_iN0301,
		testLink_o => testLink_oN0301,
		retransmission_i => retransmission_iN0301,
		retransmission_o => retransmission_oN0301);

	Router0401 : Entity work.RouterCC
	generic map( address => ADDRESSN0401 )
	port map(
		clock    => clock(N0401),
		reset    => reset,
		clock_rx => clock_rxN0401,
		rx       => rxN0401,
		data_in  => data_inN0401,
		credit_o => credit_oN0401,
		clock_tx => clock_txN0401,
		tx       => txN0401,
		data_out => data_outN0401,
		credit_i => credit_iN0401,
		testLink_i => testLink_iN0401,
		testLink_o => testLink_oN0401,
		retransmission_i => retransmission_iN0401,
		retransmission_o => retransmission_oN0401);

	Router0002 : Entity work.RouterCC
	generic map( address => ADDRESSN0002 )
	port map(
		clock    => clock(N0002),
		reset    => reset,
		clock_rx => clock_rxN0002,
		rx       => rxN0002,
		data_in  => data_inN0002,
		credit_o => credit_oN0002,
		clock_tx => clock_txN0002,
		tx       => txN0002,
		data_out => data_outN0002,
		credit_i => credit_iN0002,
		testLink_i => testLink_iN0002,
		testLink_o => testLink_oN0002,
		retransmission_i => retransmission_iN0002,
		retransmission_o => retransmission_oN0002);

	Router0102 : Entity work.RouterCC
	generic map( address => ADDRESSN0102 )
	port map(
		clock    => clock(N0102),
		reset    => reset,
		clock_rx => clock_rxN0102,
		rx       => rxN0102,
		data_in  => data_inN0102,
		credit_o => credit_oN0102,
		clock_tx => clock_txN0102,
		tx       => txN0102,
		data_out => data_outN0102,
		credit_i => credit_iN0102,
		testLink_i => testLink_iN0102,
		testLink_o => testLink_oN0102,
		retransmission_i => retransmission_iN0102,
		retransmission_o => retransmission_oN0102);

	Router0202 : Entity work.RouterCC
	generic map( address => ADDRESSN0202 )
	port map(
		clock    => clock(N0202),
		reset    => reset,
		clock_rx => clock_rxN0202,
		rx       => rxN0202,
		data_in  => data_inN0202,
		credit_o => credit_oN0202,
		clock_tx => clock_txN0202,
		tx       => txN0202,
		data_out => data_outN0202,
		credit_i => credit_iN0202,
		testLink_i => testLink_iN0202,
		testLink_o => testLink_oN0202,
		retransmission_i => retransmission_iN0202,
		retransmission_o => retransmission_oN0202);

	Router0302 : Entity work.RouterCC
	generic map( address => ADDRESSN0302 )
	port map(
		clock    => clock(N0302),
		reset    => reset,
		clock_rx => clock_rxN0302,
		rx       => rxN0302,
		data_in  => data_inN0302,
		credit_o => credit_oN0302,
		clock_tx => clock_txN0302,
		tx       => txN0302,
		data_out => data_outN0302,
		credit_i => credit_iN0302,
		testLink_i => testLink_iN0302,
		testLink_o => testLink_oN0302,
		retransmission_i => retransmission_iN0302,
		retransmission_o => retransmission_oN0302);

	Router0402 : Entity work.RouterCC
	generic map( address => ADDRESSN0402 )
	port map(
		clock    => clock(N0402),
		reset    => reset,
		clock_rx => clock_rxN0402,
		rx       => rxN0402,
		data_in  => data_inN0402,
		credit_o => credit_oN0402,
		clock_tx => clock_txN0402,
		tx       => txN0402,
		data_out => data_outN0402,
		credit_i => credit_iN0402,
		testLink_i => testLink_iN0402,
		testLink_o => testLink_oN0402,
		retransmission_i => retransmission_iN0402,
		retransmission_o => retransmission_oN0402);

	Router0003 : Entity work.RouterCC
	generic map( address => ADDRESSN0003 )
	port map(
		clock    => clock(N0003),
		reset    => reset,
		clock_rx => clock_rxN0003,
		rx       => rxN0003,
		data_in  => data_inN0003,
		credit_o => credit_oN0003,
		clock_tx => clock_txN0003,
		tx       => txN0003,
		data_out => data_outN0003,
		credit_i => credit_iN0003,
		testLink_i => testLink_iN0003,
		testLink_o => testLink_oN0003,
		retransmission_i => retransmission_iN0003,
		retransmission_o => retransmission_oN0003);

	Router0103 : Entity work.RouterCC
	generic map( address => ADDRESSN0103 )
	port map(
		clock    => clock(N0103),
		reset    => reset,
		clock_rx => clock_rxN0103,
		rx       => rxN0103,
		data_in  => data_inN0103,
		credit_o => credit_oN0103,
		clock_tx => clock_txN0103,
		tx       => txN0103,
		data_out => data_outN0103,
		credit_i => credit_iN0103,
		testLink_i => testLink_iN0103,
		testLink_o => testLink_oN0103,
		retransmission_i => retransmission_iN0103,
		retransmission_o => retransmission_oN0103);

	Router0203 : Entity work.RouterCC
	generic map( address => ADDRESSN0203 )
	port map(
		clock    => clock(N0203),
		reset    => reset,
		clock_rx => clock_rxN0203,
		rx       => rxN0203,
		data_in  => data_inN0203,
		credit_o => credit_oN0203,
		clock_tx => clock_txN0203,
		tx       => txN0203,
		data_out => data_outN0203,
		credit_i => credit_iN0203,
		testLink_i => testLink_iN0203,
		testLink_o => testLink_oN0203,
		retransmission_i => retransmission_iN0203,
		retransmission_o => retransmission_oN0203);

	Router0303 : Entity work.RouterCC
	generic map( address => ADDRESSN0303 )
	port map(
		clock    => clock(N0303),
		reset    => reset,
		clock_rx => clock_rxN0303,
		rx       => rxN0303,
		data_in  => data_inN0303,
		credit_o => credit_oN0303,
		clock_tx => clock_txN0303,
		tx       => txN0303,
		data_out => data_outN0303,
		credit_i => credit_iN0303,
		testLink_i => testLink_iN0303,
		testLink_o => testLink_oN0303,
		retransmission_i => retransmission_iN0303,
		retransmission_o => retransmission_oN0303);

	Router0403 : Entity work.RouterCC
	generic map( address => ADDRESSN0403 )
	port map(
		clock    => clock(N0403),
		reset    => reset,
		clock_rx => clock_rxN0403,
		rx       => rxN0403,
		data_in  => data_inN0403,
		credit_o => credit_oN0403,
		clock_tx => clock_txN0403,
		tx       => txN0403,
		data_out => data_outN0403,
		credit_i => credit_iN0403,
		testLink_i => testLink_iN0403,
		testLink_o => testLink_oN0403,
		retransmission_i => retransmission_iN0403,
		retransmission_o => retransmission_oN0403);

	Router0004 : Entity work.RouterCC
	generic map( address => ADDRESSN0004 )
	port map(
		clock    => clock(N0004),
		reset    => reset,
		clock_rx => clock_rxN0004,
		rx       => rxN0004,
		data_in  => data_inN0004,
		credit_o => credit_oN0004,
		clock_tx => clock_txN0004,
		tx       => txN0004,
		data_out => data_outN0004,
		credit_i => credit_iN0004,
		testLink_i => testLink_iN0004,
		testLink_o => testLink_oN0004,
		retransmission_i => retransmission_iN0004,
		retransmission_o => retransmission_oN0004);

	Router0104 : Entity work.RouterCC
	generic map( address => ADDRESSN0104 )
	port map(
		clock    => clock(N0104),
		reset    => reset,
		clock_rx => clock_rxN0104,
		rx       => rxN0104,
		data_in  => data_inN0104,
		credit_o => credit_oN0104,
		clock_tx => clock_txN0104,
		tx       => txN0104,
		data_out => data_outN0104,
		credit_i => credit_iN0104,
		testLink_i => testLink_iN0104,
		testLink_o => testLink_oN0104,
		retransmission_i => retransmission_iN0104,
		retransmission_o => retransmission_oN0104);

	Router0204 : Entity work.RouterCC
	generic map( address => ADDRESSN0204 )
	port map(
		clock    => clock(N0204),
		reset    => reset,
		clock_rx => clock_rxN0204,
		rx       => rxN0204,
		data_in  => data_inN0204,
		credit_o => credit_oN0204,
		clock_tx => clock_txN0204,
		tx       => txN0204,
		data_out => data_outN0204,
		credit_i => credit_iN0204,
		testLink_i => testLink_iN0204,
		testLink_o => testLink_oN0204,
		retransmission_i => retransmission_iN0204,
		retransmission_o => retransmission_oN0204);

	Router0304 : Entity work.RouterCC
	generic map( address => ADDRESSN0304 )
	port map(
		clock    => clock(N0304),
		reset    => reset,
		clock_rx => clock_rxN0304,
		rx       => rxN0304,
		data_in  => data_inN0304,
		credit_o => credit_oN0304,
		clock_tx => clock_txN0304,
		tx       => txN0304,
		data_out => data_outN0304,
		credit_i => credit_iN0304,
		testLink_i => testLink_iN0304,
		testLink_o => testLink_oN0304,
		retransmission_i => retransmission_iN0304,
		retransmission_o => retransmission_oN0304);

	Router0404 : Entity work.RouterCC
	generic map( address => ADDRESSN0404 )
	port map(
		clock    => clock(N0404),
		reset    => reset,
		clock_rx => clock_rxN0404,
		rx       => rxN0404,
		data_in  => data_inN0404,
		credit_o => credit_oN0404,
		clock_tx => clock_txN0404,
		tx       => txN0404,
		data_out => data_outN0404,
		credit_i => credit_iN0404,
		testLink_i => testLink_iN0404,
		testLink_o => testLink_oN0404,
		retransmission_i => retransmission_iN0404,
		retransmission_o => retransmission_oN0404);

	-- ROUTER 0000
	-- EAST port
	clock_rxN0000(0)<=clock_txN0100(1);
	rxN0000(0)<=txN0100(1);
	data_inN0000(0)<=data_outN0100(1);
	credit_iN0000(0)<=credit_oN0100(1);
   testLink_iN0000(0)<=testLink_oN0100(1);
   retransmission_iN0000(0)<=retransmission_oN0100(1);
	-- WEST port
	clock_rxN0000(1)<='0';
	rxN0000(1)<='0';
	data_inN0000(1)<=(others=>'0');
	credit_iN0000(1)<='0';
	testLink_iN0000(1)<='0';
	retransmission_iN0000(1)<='0';
	-- NORTH port
	clock_rxN0000(2)<=clock_txN0001(3);
	rxN0000(2)<=txN0001(3);
	data_inN0000(2)<=data_outN0001(3);
	credit_iN0000(2)<=credit_oN0001(3);
	testLink_iN0000(2)<=testLink_oN0001(3);
	retransmission_iN0000(2)<=retransmission_oN0001(3);
	-- SOUTH port
	clock_rxN0000(3)<='0';
	rxN0000(3)<='0';
	data_inN0000(3)<=(others=>'0');
	credit_iN0000(3)<='0';
	testLink_iN0000(3)<='0';
	retransmission_iN0000(3)<='0';
	-- LOCAL port
	clock_rxN0000(4)<=clock_rxLocal(N0000);
	rxN0000(4)<=rxLocal(N0000);
	data_inN0000(4)<=data_inLocal(N0000);
	credit_iN0000(4)<=credit_iLocal(N0000);
	testLink_iN0000(4)<='0';
	clock_txLocal(N0000)<=clock_txN0000(4);
	txLocal(N0000)<=txN0000(4);
	data_outLocal(N0000)<=data_outN0000(4);
	credit_oLocal(N0000)<=credit_oN0000(4);
	retransmission_iN0000(4)<='0';

	-- ROUTER 0100
	-- EAST port
	clock_rxN0100(0)<=clock_txN0200(1);
	rxN0100(0)<=txN0200(1);
	data_inN0100(0)<=data_outN0200(1);
	credit_iN0100(0)<=credit_oN0200(1);
   testLink_iN0100(0)<=testLink_oN0200(1);
   retransmission_iN0100(0)<=retransmission_oN0200(1);
	-- WEST port
	clock_rxN0100(1)<=clock_txN0000(0);
	rxN0100(1)<=txN0000(0);
	data_inN0100(1)<=data_outN0000(0);
	credit_iN0100(1)<=credit_oN0000(0);
	testLink_iN0100(1)<=testLink_oN0000(0);
	retransmission_iN0100(1)<=retransmission_oN0000(0);
	-- NORTH port
	clock_rxN0100(2)<=clock_txN0101(3);
	rxN0100(2)<=txN0101(3);
	data_inN0100(2)<=data_outN0101(3);
	credit_iN0100(2)<=credit_oN0101(3);
	testLink_iN0100(2)<=testLink_oN0101(3);
	retransmission_iN0100(2)<=retransmission_oN0101(3);
	-- SOUTH port
	clock_rxN0100(3)<='0';
	rxN0100(3)<='0';
	data_inN0100(3)<=(others=>'0');
	credit_iN0100(3)<='0';
	testLink_iN0100(3)<='0';
	retransmission_iN0100(3)<='0';
	-- LOCAL port
	clock_rxN0100(4)<=clock_rxLocal(N0100);
	rxN0100(4)<=rxLocal(N0100);
	data_inN0100(4)<=data_inLocal(N0100);
	credit_iN0100(4)<=credit_iLocal(N0100);
	testLink_iN0100(4)<='0';
	clock_txLocal(N0100)<=clock_txN0100(4);
	txLocal(N0100)<=txN0100(4);
	data_outLocal(N0100)<=data_outN0100(4);
	credit_oLocal(N0100)<=credit_oN0100(4);
	retransmission_iN0100(4)<='0';

	-- ROUTER 0200
	-- EAST port
	clock_rxN0200(0)<=clock_txN0300(1);
	rxN0200(0)<=txN0300(1);
	data_inN0200(0)<=data_outN0300(1);
	credit_iN0200(0)<=credit_oN0300(1);
   testLink_iN0200(0)<=testLink_oN0300(1);
   retransmission_iN0200(0)<=retransmission_oN0300(1);
	-- WEST port
	clock_rxN0200(1)<=clock_txN0100(0);
	rxN0200(1)<=txN0100(0);
	data_inN0200(1)<=data_outN0100(0);
	credit_iN0200(1)<=credit_oN0100(0);
	testLink_iN0200(1)<=testLink_oN0100(0);
	retransmission_iN0200(1)<=retransmission_oN0100(0);
	-- NORTH port
	clock_rxN0200(2)<=clock_txN0201(3);
	rxN0200(2)<=txN0201(3);
	data_inN0200(2)<=data_outN0201(3);
	credit_iN0200(2)<=credit_oN0201(3);
	testLink_iN0200(2)<=testLink_oN0201(3);
	retransmission_iN0200(2)<=retransmission_oN0201(3);
	-- SOUTH port
	clock_rxN0200(3)<='0';
	rxN0200(3)<='0';
	data_inN0200(3)<=(others=>'0');
	credit_iN0200(3)<='0';
	testLink_iN0200(3)<='0';
	retransmission_iN0200(3)<='0';
	-- LOCAL port
	clock_rxN0200(4)<=clock_rxLocal(N0200);
	rxN0200(4)<=rxLocal(N0200);
	data_inN0200(4)<=data_inLocal(N0200);
	credit_iN0200(4)<=credit_iLocal(N0200);
	testLink_iN0200(4)<='0';
	clock_txLocal(N0200)<=clock_txN0200(4);
	txLocal(N0200)<=txN0200(4);
	data_outLocal(N0200)<=data_outN0200(4);
	credit_oLocal(N0200)<=credit_oN0200(4);
	retransmission_iN0200(4)<='0';

	-- ROUTER 0300
	-- EAST port
	clock_rxN0300(0)<=clock_txN0400(1);
	rxN0300(0)<=txN0400(1);
	data_inN0300(0)<=data_outN0400(1);
	credit_iN0300(0)<=credit_oN0400(1);
   testLink_iN0300(0)<=testLink_oN0400(1);
   retransmission_iN0300(0)<=retransmission_oN0400(1);
	-- WEST port
	clock_rxN0300(1)<=clock_txN0200(0);
	rxN0300(1)<=txN0200(0);
	data_inN0300(1)<=data_outN0200(0);
	credit_iN0300(1)<=credit_oN0200(0);
	testLink_iN0300(1)<=testLink_oN0200(0);
	retransmission_iN0300(1)<=retransmission_oN0200(0);
	-- NORTH port
	clock_rxN0300(2)<=clock_txN0301(3);
	rxN0300(2)<=txN0301(3);
	data_inN0300(2)<=data_outN0301(3);
	credit_iN0300(2)<=credit_oN0301(3);
	testLink_iN0300(2)<=testLink_oN0301(3);
	retransmission_iN0300(2)<=retransmission_oN0301(3);
	-- SOUTH port
	clock_rxN0300(3)<='0';
	rxN0300(3)<='0';
	data_inN0300(3)<=(others=>'0');
	credit_iN0300(3)<='0';
	testLink_iN0300(3)<='0';
	retransmission_iN0300(3)<='0';
	-- LOCAL port
	clock_rxN0300(4)<=clock_rxLocal(N0300);
	rxN0300(4)<=rxLocal(N0300);
	data_inN0300(4)<=data_inLocal(N0300);
	credit_iN0300(4)<=credit_iLocal(N0300);
	testLink_iN0300(4)<='0';
	clock_txLocal(N0300)<=clock_txN0300(4);
	txLocal(N0300)<=txN0300(4);
	data_outLocal(N0300)<=data_outN0300(4);
	credit_oLocal(N0300)<=credit_oN0300(4);
	retransmission_iN0300(4)<='0';

	-- ROUTER 0400
	-- EAST port
	clock_rxN0400(0)<='0';
	rxN0400(0)<='0';
	data_inN0400(0)<=(others=>'0');
	credit_iN0400(0)<='0';
   testLink_iN0400(0)<='0';
   retransmission_iN0400(0)<='0';
	-- WEST port
	clock_rxN0400(1)<=clock_txN0300(0);
	rxN0400(1)<=txN0300(0);
	data_inN0400(1)<=data_outN0300(0);
	credit_iN0400(1)<=credit_oN0300(0);
	testLink_iN0400(1)<=testLink_oN0300(0);
	retransmission_iN0400(1)<=retransmission_oN0300(0);
	-- NORTH port
	clock_rxN0400(2)<=clock_txN0401(3);
	rxN0400(2)<=txN0401(3);
	data_inN0400(2)<=data_outN0401(3);
	credit_iN0400(2)<=credit_oN0401(3);
	testLink_iN0400(2)<=testLink_oN0401(3);
	retransmission_iN0400(2)<=retransmission_oN0401(3);
	-- SOUTH port
	clock_rxN0400(3)<='0';
	rxN0400(3)<='0';
	data_inN0400(3)<=(others=>'0');
	credit_iN0400(3)<='0';
	testLink_iN0400(3)<='0';
	retransmission_iN0400(3)<='0';
	-- LOCAL port
	clock_rxN0400(4)<=clock_rxLocal(N0400);
	rxN0400(4)<=rxLocal(N0400);
	data_inN0400(4)<=data_inLocal(N0400);
	credit_iN0400(4)<=credit_iLocal(N0400);
	testLink_iN0400(4)<='0';
	clock_txLocal(N0400)<=clock_txN0400(4);
	txLocal(N0400)<=txN0400(4);
	data_outLocal(N0400)<=data_outN0400(4);
	credit_oLocal(N0400)<=credit_oN0400(4);
	retransmission_iN0400(4)<='0';

	-- ROUTER 0001
	-- EAST port
	clock_rxN0001(0)<=clock_txN0101(1);
	rxN0001(0)<=txN0101(1);
	data_inN0001(0)<=data_outN0101(1);
	credit_iN0001(0)<=credit_oN0101(1);
   testLink_iN0001(0)<=testLink_oN0101(1);
   retransmission_iN0001(0)<=retransmission_oN0101(1);
	-- WEST port
	clock_rxN0001(1)<='0';
	rxN0001(1)<='0';
	data_inN0001(1)<=(others=>'0');
	credit_iN0001(1)<='0';
	testLink_iN0001(1)<='0';
	retransmission_iN0001(1)<='0';
	-- NORTH port
	clock_rxN0001(2)<=clock_txN0002(3);
	rxN0001(2)<=txN0002(3);
	data_inN0001(2)<=data_outN0002(3);
	credit_iN0001(2)<=credit_oN0002(3);
	testLink_iN0001(2)<=testLink_oN0002(3);
	retransmission_iN0001(2)<=retransmission_oN0002(3);
	-- SOUTH port
	clock_rxN0001(3)<=clock_txN0000(2);
	rxN0001(3)<=txN0000(2);
	data_inN0001(3)<=data_outN0000(2);
	credit_iN0001(3)<=credit_oN0000(2);
	testLink_iN0001(3)<=testLink_oN0000(2);
	retransmission_iN0001(3)<=retransmission_oN0000(2);
	-- LOCAL port
	clock_rxN0001(4)<=clock_rxLocal(N0001);
	rxN0001(4)<=rxLocal(N0001);
	data_inN0001(4)<=data_inLocal(N0001);
	credit_iN0001(4)<=credit_iLocal(N0001);
	testLink_iN0001(4)<='0';
	clock_txLocal(N0001)<=clock_txN0001(4);
	txLocal(N0001)<=txN0001(4);
	data_outLocal(N0001)<=data_outN0001(4);
	credit_oLocal(N0001)<=credit_oN0001(4);
	retransmission_iN0001(4)<='0';

	-- ROUTER 0101
	-- EAST port
	clock_rxN0101(0)<=clock_txN0201(1);
	rxN0101(0)<=txN0201(1);
	data_inN0101(0)<=data_outN0201(1);
	credit_iN0101(0)<=credit_oN0201(1);
   testLink_iN0101(0)<=testLink_oN0201(1);
   retransmission_iN0101(0)<=retransmission_oN0201(1);
	-- WEST port
	clock_rxN0101(1)<=clock_txN0001(0);
	rxN0101(1)<=txN0001(0);
	data_inN0101(1)<=data_outN0001(0);
	credit_iN0101(1)<=credit_oN0001(0);
	testLink_iN0101(1)<=testLink_oN0001(0);
	retransmission_iN0101(1)<=retransmission_oN0001(0);
	-- NORTH port
	clock_rxN0101(2)<=clock_txN0102(3);
	rxN0101(2)<=txN0102(3);
	data_inN0101(2)<=data_outN0102(3);
	credit_iN0101(2)<=credit_oN0102(3);
	testLink_iN0101(2)<=testLink_oN0102(3);
	retransmission_iN0101(2)<=retransmission_oN0102(3);
	-- SOUTH port
	clock_rxN0101(3)<=clock_txN0100(2);
	rxN0101(3)<=txN0100(2);
	data_inN0101(3)<=data_outN0100(2);
	credit_iN0101(3)<=credit_oN0100(2);
	testLink_iN0101(3)<=testLink_oN0100(2);
	retransmission_iN0101(3)<=retransmission_oN0100(2);
	-- LOCAL port
	clock_rxN0101(4)<=clock_rxLocal(N0101);
	rxN0101(4)<=rxLocal(N0101);
	data_inN0101(4)<=data_inLocal(N0101);
	credit_iN0101(4)<=credit_iLocal(N0101);
	testLink_iN0101(4)<='0';
	clock_txLocal(N0101)<=clock_txN0101(4);
	txLocal(N0101)<=txN0101(4);
	data_outLocal(N0101)<=data_outN0101(4);
	credit_oLocal(N0101)<=credit_oN0101(4);
	retransmission_iN0101(4)<='0';

	-- ROUTER 0201
	-- EAST port
	clock_rxN0201(0)<=clock_txN0301(1);
	rxN0201(0)<=txN0301(1);
	data_inN0201(0)<=data_outN0301(1);
	credit_iN0201(0)<=credit_oN0301(1);
   testLink_iN0201(0)<=testLink_oN0301(1);
   retransmission_iN0201(0)<=retransmission_oN0301(1);
	-- WEST port
	clock_rxN0201(1)<=clock_txN0101(0);
	rxN0201(1)<=txN0101(0);
	data_inN0201(1)<=data_outN0101(0);
	credit_iN0201(1)<=credit_oN0101(0);
	testLink_iN0201(1)<=testLink_oN0101(0);
	retransmission_iN0201(1)<=retransmission_oN0101(0);
	-- NORTH port
	clock_rxN0201(2)<=clock_txN0202(3);
	rxN0201(2)<=txN0202(3);
	data_inN0201(2)<=data_outN0202(3);
	credit_iN0201(2)<=credit_oN0202(3);
	testLink_iN0201(2)<=testLink_oN0202(3);
	retransmission_iN0201(2)<=retransmission_oN0202(3);
	-- SOUTH port
	clock_rxN0201(3)<=clock_txN0200(2);
	rxN0201(3)<=txN0200(2);
	data_inN0201(3)<=data_outN0200(2);
	credit_iN0201(3)<=credit_oN0200(2);
	testLink_iN0201(3)<=testLink_oN0200(2);
	retransmission_iN0201(3)<=retransmission_oN0200(2);
	-- LOCAL port
	clock_rxN0201(4)<=clock_rxLocal(N0201);
	rxN0201(4)<=rxLocal(N0201);
	data_inN0201(4)<=data_inLocal(N0201);
	credit_iN0201(4)<=credit_iLocal(N0201);
	testLink_iN0201(4)<='0';
	clock_txLocal(N0201)<=clock_txN0201(4);
	txLocal(N0201)<=txN0201(4);
	data_outLocal(N0201)<=data_outN0201(4);
	credit_oLocal(N0201)<=credit_oN0201(4);
	retransmission_iN0201(4)<='0';

	-- ROUTER 0301
	-- EAST port
	clock_rxN0301(0)<=clock_txN0401(1);
	rxN0301(0)<=txN0401(1);
	data_inN0301(0)<=data_outN0401(1);
	credit_iN0301(0)<=credit_oN0401(1);
   testLink_iN0301(0)<=testLink_oN0401(1);
   retransmission_iN0301(0)<=retransmission_oN0401(1);
	-- WEST port
	clock_rxN0301(1)<=clock_txN0201(0);
	rxN0301(1)<=txN0201(0);
	data_inN0301(1)<=data_outN0201(0);
	credit_iN0301(1)<=credit_oN0201(0);
	testLink_iN0301(1)<=testLink_oN0201(0);
	retransmission_iN0301(1)<=retransmission_oN0201(0);
	-- NORTH port
	clock_rxN0301(2)<=clock_txN0302(3);
	rxN0301(2)<=txN0302(3);
	data_inN0301(2)<=data_outN0302(3);
	credit_iN0301(2)<=credit_oN0302(3);
	testLink_iN0301(2)<=testLink_oN0302(3);
	retransmission_iN0301(2)<=retransmission_oN0302(3);
	-- SOUTH port
	clock_rxN0301(3)<=clock_txN0300(2);
	rxN0301(3)<=txN0300(2);
	data_inN0301(3)<=data_outN0300(2);
	credit_iN0301(3)<=credit_oN0300(2);
	testLink_iN0301(3)<=testLink_oN0300(2);
	retransmission_iN0301(3)<=retransmission_oN0300(2);
	-- LOCAL port
	clock_rxN0301(4)<=clock_rxLocal(N0301);
	rxN0301(4)<=rxLocal(N0301);
	data_inN0301(4)<=data_inLocal(N0301);
	credit_iN0301(4)<=credit_iLocal(N0301);
	testLink_iN0301(4)<='0';
	clock_txLocal(N0301)<=clock_txN0301(4);
	txLocal(N0301)<=txN0301(4);
	data_outLocal(N0301)<=data_outN0301(4);
	credit_oLocal(N0301)<=credit_oN0301(4);
	retransmission_iN0301(4)<='0';

	-- ROUTER 0401
	-- EAST port
	clock_rxN0401(0)<='0';
	rxN0401(0)<='0';
	data_inN0401(0)<=(others=>'0');
	credit_iN0401(0)<='0';
   testLink_iN0401(0)<='0';
   retransmission_iN0401(0)<='0';
	-- WEST port
	clock_rxN0401(1)<=clock_txN0301(0);
	rxN0401(1)<=txN0301(0);
	data_inN0401(1)<=data_outN0301(0);
	credit_iN0401(1)<=credit_oN0301(0);
	testLink_iN0401(1)<=testLink_oN0301(0);
	retransmission_iN0401(1)<=retransmission_oN0301(0);
	-- NORTH port
	clock_rxN0401(2)<=clock_txN0402(3);
	rxN0401(2)<=txN0402(3);
	data_inN0401(2)<=data_outN0402(3);
	credit_iN0401(2)<=credit_oN0402(3);
	testLink_iN0401(2)<=testLink_oN0402(3);
	retransmission_iN0401(2)<=retransmission_oN0402(3);
	-- SOUTH port
	clock_rxN0401(3)<=clock_txN0400(2);
	rxN0401(3)<=txN0400(2);
	data_inN0401(3)<=data_outN0400(2);
	credit_iN0401(3)<=credit_oN0400(2);
	testLink_iN0401(3)<=testLink_oN0400(2);
	retransmission_iN0401(3)<=retransmission_oN0400(2);
	-- LOCAL port
	clock_rxN0401(4)<=clock_rxLocal(N0401);
	rxN0401(4)<=rxLocal(N0401);
	data_inN0401(4)<=data_inLocal(N0401);
	credit_iN0401(4)<=credit_iLocal(N0401);
	testLink_iN0401(4)<='0';
	clock_txLocal(N0401)<=clock_txN0401(4);
	txLocal(N0401)<=txN0401(4);
	data_outLocal(N0401)<=data_outN0401(4);
	credit_oLocal(N0401)<=credit_oN0401(4);
	retransmission_iN0401(4)<='0';

	-- ROUTER 0002
	-- EAST port
	clock_rxN0002(0)<=clock_txN0102(1);
	rxN0002(0)<=txN0102(1);
	data_inN0002(0)<=data_outN0102(1);
	credit_iN0002(0)<=credit_oN0102(1);
   testLink_iN0002(0)<=testLink_oN0102(1);
   retransmission_iN0002(0)<=retransmission_oN0102(1);
	-- WEST port
	clock_rxN0002(1)<='0';
	rxN0002(1)<='0';
	data_inN0002(1)<=(others=>'0');
	credit_iN0002(1)<='0';
	testLink_iN0002(1)<='0';
	retransmission_iN0002(1)<='0';
	-- NORTH port
	clock_rxN0002(2)<=clock_txN0003(3);
	rxN0002(2)<=txN0003(3);
	data_inN0002(2)<=data_outN0003(3);
	credit_iN0002(2)<=credit_oN0003(3);
	testLink_iN0002(2)<=testLink_oN0003(3);
	retransmission_iN0002(2)<=retransmission_oN0003(3);
	-- SOUTH port
	clock_rxN0002(3)<=clock_txN0001(2);
	rxN0002(3)<=txN0001(2);
	data_inN0002(3)<=data_outN0001(2);
	credit_iN0002(3)<=credit_oN0001(2);
	testLink_iN0002(3)<=testLink_oN0001(2);
	retransmission_iN0002(3)<=retransmission_oN0001(2);
	-- LOCAL port
	clock_rxN0002(4)<=clock_rxLocal(N0002);
	rxN0002(4)<=rxLocal(N0002);
	data_inN0002(4)<=data_inLocal(N0002);
	credit_iN0002(4)<=credit_iLocal(N0002);
	testLink_iN0002(4)<='0';
	clock_txLocal(N0002)<=clock_txN0002(4);
	txLocal(N0002)<=txN0002(4);
	data_outLocal(N0002)<=data_outN0002(4);
	credit_oLocal(N0002)<=credit_oN0002(4);
	retransmission_iN0002(4)<='0';

	-- ROUTER 0102
	-- EAST port
	clock_rxN0102(0)<=clock_txN0202(1);
	rxN0102(0)<=txN0202(1);
	data_inN0102(0)<=data_outN0202(1);
	credit_iN0102(0)<=credit_oN0202(1);
   testLink_iN0102(0)<=testLink_oN0202(1);
   retransmission_iN0102(0)<=retransmission_oN0202(1);
	-- WEST port
	clock_rxN0102(1)<=clock_txN0002(0);
	rxN0102(1)<=txN0002(0);
	data_inN0102(1)<=data_outN0002(0);
	credit_iN0102(1)<=credit_oN0002(0);
	testLink_iN0102(1)<=testLink_oN0002(0);
	retransmission_iN0102(1)<=retransmission_oN0002(0);
	-- NORTH port
	clock_rxN0102(2)<=clock_txN0103(3);
	rxN0102(2)<=txN0103(3);
	data_inN0102(2)<=data_outN0103(3);
	credit_iN0102(2)<=credit_oN0103(3);
	testLink_iN0102(2)<=testLink_oN0103(3);
	retransmission_iN0102(2)<=retransmission_oN0103(3);
	-- SOUTH port
	clock_rxN0102(3)<=clock_txN0101(2);
	rxN0102(3)<=txN0101(2);
	data_inN0102(3)<=data_outN0101(2);
	credit_iN0102(3)<=credit_oN0101(2);
	testLink_iN0102(3)<=testLink_oN0101(2);
	retransmission_iN0102(3)<=retransmission_oN0101(2);
	-- LOCAL port
	clock_rxN0102(4)<=clock_rxLocal(N0102);
	rxN0102(4)<=rxLocal(N0102);
	data_inN0102(4)<=data_inLocal(N0102);
	credit_iN0102(4)<=credit_iLocal(N0102);
	testLink_iN0102(4)<='0';
	clock_txLocal(N0102)<=clock_txN0102(4);
	txLocal(N0102)<=txN0102(4);
	data_outLocal(N0102)<=data_outN0102(4);
	credit_oLocal(N0102)<=credit_oN0102(4);
	retransmission_iN0102(4)<='0';

	-- ROUTER 0202
	-- EAST port
	clock_rxN0202(0)<=clock_txN0302(1);
	rxN0202(0)<=txN0302(1);
	data_inN0202(0)<=data_outN0302(1);
	credit_iN0202(0)<=credit_oN0302(1);
   testLink_iN0202(0)<=testLink_oN0302(1);
   retransmission_iN0202(0)<=retransmission_oN0302(1);
	-- WEST port
	clock_rxN0202(1)<=clock_txN0102(0);
	rxN0202(1)<=txN0102(0);
	data_inN0202(1)<=data_outN0102(0);
	credit_iN0202(1)<=credit_oN0102(0);
	testLink_iN0202(1)<=testLink_oN0102(0);
	retransmission_iN0202(1)<=retransmission_oN0102(0);
	-- NORTH port
	clock_rxN0202(2)<=clock_txN0203(3);
	rxN0202(2)<=txN0203(3);
	data_inN0202(2)<=data_outN0203(3);
	credit_iN0202(2)<=credit_oN0203(3);
	testLink_iN0202(2)<=testLink_oN0203(3);
	retransmission_iN0202(2)<=retransmission_oN0203(3);
	-- SOUTH port
	clock_rxN0202(3)<=clock_txN0201(2);
	rxN0202(3)<=txN0201(2);
	data_inN0202(3)<=data_outN0201(2);
	credit_iN0202(3)<=credit_oN0201(2);
	testLink_iN0202(3)<=testLink_oN0201(2);
	retransmission_iN0202(3)<=retransmission_oN0201(2);
	-- LOCAL port
	clock_rxN0202(4)<=clock_rxLocal(N0202);
	rxN0202(4)<=rxLocal(N0202);
	data_inN0202(4)<=data_inLocal(N0202);
	credit_iN0202(4)<=credit_iLocal(N0202);
	testLink_iN0202(4)<='0';
	clock_txLocal(N0202)<=clock_txN0202(4);
	txLocal(N0202)<=txN0202(4);
	data_outLocal(N0202)<=data_outN0202(4);
	credit_oLocal(N0202)<=credit_oN0202(4);
	retransmission_iN0202(4)<='0';

	-- ROUTER 0302
	-- EAST port
	clock_rxN0302(0)<=clock_txN0402(1);
	rxN0302(0)<=txN0402(1);
	data_inN0302(0)<=data_outN0402(1);
	credit_iN0302(0)<=credit_oN0402(1);
   testLink_iN0302(0)<=testLink_oN0402(1);
   retransmission_iN0302(0)<=retransmission_oN0402(1);
	-- WEST port
	clock_rxN0302(1)<=clock_txN0202(0);
	rxN0302(1)<=txN0202(0);
	data_inN0302(1)<=data_outN0202(0);
	credit_iN0302(1)<=credit_oN0202(0);
	testLink_iN0302(1)<=testLink_oN0202(0);
	retransmission_iN0302(1)<=retransmission_oN0202(0);
	-- NORTH port
	clock_rxN0302(2)<=clock_txN0303(3);
	rxN0302(2)<=txN0303(3);
	data_inN0302(2)<=data_outN0303(3);
	credit_iN0302(2)<=credit_oN0303(3);
	testLink_iN0302(2)<=testLink_oN0303(3);
	retransmission_iN0302(2)<=retransmission_oN0303(3);
	-- SOUTH port
	clock_rxN0302(3)<=clock_txN0301(2);
	rxN0302(3)<=txN0301(2);
	data_inN0302(3)<=data_outN0301(2);
	credit_iN0302(3)<=credit_oN0301(2);
	testLink_iN0302(3)<=testLink_oN0301(2);
	retransmission_iN0302(3)<=retransmission_oN0301(2);
	-- LOCAL port
	clock_rxN0302(4)<=clock_rxLocal(N0302);
	rxN0302(4)<=rxLocal(N0302);
	data_inN0302(4)<=data_inLocal(N0302);
	credit_iN0302(4)<=credit_iLocal(N0302);
	testLink_iN0302(4)<='0';
	clock_txLocal(N0302)<=clock_txN0302(4);
	txLocal(N0302)<=txN0302(4);
	data_outLocal(N0302)<=data_outN0302(4);
	credit_oLocal(N0302)<=credit_oN0302(4);
	retransmission_iN0302(4)<='0';

	-- ROUTER 0402
	-- EAST port
	clock_rxN0402(0)<='0';
	rxN0402(0)<='0';
	data_inN0402(0)<=(others=>'0');
	credit_iN0402(0)<='0';
   testLink_iN0402(0)<='0';
   retransmission_iN0402(0)<='0';
	-- WEST port
	clock_rxN0402(1)<=clock_txN0302(0);
	rxN0402(1)<=txN0302(0);
	data_inN0402(1)<=data_outN0302(0);
	credit_iN0402(1)<=credit_oN0302(0);
	testLink_iN0402(1)<=testLink_oN0302(0);
	retransmission_iN0402(1)<=retransmission_oN0302(0);
	-- NORTH port
	clock_rxN0402(2)<=clock_txN0403(3);
	rxN0402(2)<=txN0403(3);
	data_inN0402(2)<=data_outN0403(3);
	credit_iN0402(2)<=credit_oN0403(3);
	testLink_iN0402(2)<=testLink_oN0403(3);
	retransmission_iN0402(2)<=retransmission_oN0403(3);
	-- SOUTH port
	clock_rxN0402(3)<=clock_txN0401(2);
	rxN0402(3)<=txN0401(2);
	data_inN0402(3)<=data_outN0401(2);
	credit_iN0402(3)<=credit_oN0401(2);
	testLink_iN0402(3)<=testLink_oN0401(2);
	retransmission_iN0402(3)<=retransmission_oN0401(2);
	-- LOCAL port
	clock_rxN0402(4)<=clock_rxLocal(N0402);
	rxN0402(4)<=rxLocal(N0402);
	data_inN0402(4)<=data_inLocal(N0402);
	credit_iN0402(4)<=credit_iLocal(N0402);
	testLink_iN0402(4)<='0';
	clock_txLocal(N0402)<=clock_txN0402(4);
	txLocal(N0402)<=txN0402(4);
	data_outLocal(N0402)<=data_outN0402(4);
	credit_oLocal(N0402)<=credit_oN0402(4);
	retransmission_iN0402(4)<='0';

	-- ROUTER 0003
	-- EAST port
	clock_rxN0003(0)<=clock_txN0103(1);
	rxN0003(0)<=txN0103(1);
	data_inN0003(0)<=data_outN0103(1);
	credit_iN0003(0)<=credit_oN0103(1);
   testLink_iN0003(0)<=testLink_oN0103(1);
   retransmission_iN0003(0)<=retransmission_oN0103(1);
	-- WEST port
	clock_rxN0003(1)<='0';
	rxN0003(1)<='0';
	data_inN0003(1)<=(others=>'0');
	credit_iN0003(1)<='0';
	testLink_iN0003(1)<='0';
	retransmission_iN0003(1)<='0';
	-- NORTH port
	clock_rxN0003(2)<=clock_txN0004(3);
	rxN0003(2)<=txN0004(3);
	data_inN0003(2)<=data_outN0004(3);
	credit_iN0003(2)<=credit_oN0004(3);
	testLink_iN0003(2)<=testLink_oN0004(3);
	retransmission_iN0003(2)<=retransmission_oN0004(3);
	-- SOUTH port
	clock_rxN0003(3)<=clock_txN0002(2);
	rxN0003(3)<=txN0002(2);
	data_inN0003(3)<=data_outN0002(2);
	credit_iN0003(3)<=credit_oN0002(2);
	testLink_iN0003(3)<=testLink_oN0002(2);
	retransmission_iN0003(3)<=retransmission_oN0002(2);
	-- LOCAL port
	clock_rxN0003(4)<=clock_rxLocal(N0003);
	rxN0003(4)<=rxLocal(N0003);
	data_inN0003(4)<=data_inLocal(N0003);
	credit_iN0003(4)<=credit_iLocal(N0003);
	testLink_iN0003(4)<='0';
	clock_txLocal(N0003)<=clock_txN0003(4);
	txLocal(N0003)<=txN0003(4);
	data_outLocal(N0003)<=data_outN0003(4);
	credit_oLocal(N0003)<=credit_oN0003(4);
	retransmission_iN0003(4)<='0';

	-- ROUTER 0103
	-- EAST port
	clock_rxN0103(0)<=clock_txN0203(1);
	rxN0103(0)<=txN0203(1);
	data_inN0103(0)<=data_outN0203(1);
	credit_iN0103(0)<=credit_oN0203(1);
   testLink_iN0103(0)<=testLink_oN0203(1);
   retransmission_iN0103(0)<=retransmission_oN0203(1);
	-- WEST port
	clock_rxN0103(1)<=clock_txN0003(0);
	rxN0103(1)<=txN0003(0);
	data_inN0103(1)<=data_outN0003(0);
	credit_iN0103(1)<=credit_oN0003(0);
	testLink_iN0103(1)<=testLink_oN0003(0);
	retransmission_iN0103(1)<=retransmission_oN0003(0);
	-- NORTH port
	clock_rxN0103(2)<=clock_txN0104(3);
	rxN0103(2)<=txN0104(3);
	data_inN0103(2)<=data_outN0104(3);
	credit_iN0103(2)<=credit_oN0104(3);
	testLink_iN0103(2)<=testLink_oN0104(3);
	retransmission_iN0103(2)<=retransmission_oN0104(3);
	-- SOUTH port
	clock_rxN0103(3)<=clock_txN0102(2);
	rxN0103(3)<=txN0102(2);
	data_inN0103(3)<=data_outN0102(2);
	credit_iN0103(3)<=credit_oN0102(2);
	testLink_iN0103(3)<=testLink_oN0102(2);
	retransmission_iN0103(3)<=retransmission_oN0102(2);
	-- LOCAL port
	clock_rxN0103(4)<=clock_rxLocal(N0103);
	rxN0103(4)<=rxLocal(N0103);
	data_inN0103(4)<=data_inLocal(N0103);
	credit_iN0103(4)<=credit_iLocal(N0103);
	testLink_iN0103(4)<='0';
	clock_txLocal(N0103)<=clock_txN0103(4);
	txLocal(N0103)<=txN0103(4);
	data_outLocal(N0103)<=data_outN0103(4);
	credit_oLocal(N0103)<=credit_oN0103(4);
	retransmission_iN0103(4)<='0';

	-- ROUTER 0203
	-- EAST port
	clock_rxN0203(0)<=clock_txN0303(1);
	rxN0203(0)<=txN0303(1);
	data_inN0203(0)<=data_outN0303(1);
	credit_iN0203(0)<=credit_oN0303(1);
   testLink_iN0203(0)<=testLink_oN0303(1);
   retransmission_iN0203(0)<=retransmission_oN0303(1);
	-- WEST port
	clock_rxN0203(1)<=clock_txN0103(0);
	rxN0203(1)<=txN0103(0);
	data_inN0203(1)<=data_outN0103(0);
	credit_iN0203(1)<=credit_oN0103(0);
	testLink_iN0203(1)<=testLink_oN0103(0);
	retransmission_iN0203(1)<=retransmission_oN0103(0);
	-- NORTH port
	clock_rxN0203(2)<=clock_txN0204(3);
	rxN0203(2)<=txN0204(3);
	data_inN0203(2)<=data_outN0204(3);
	credit_iN0203(2)<=credit_oN0204(3);
	testLink_iN0203(2)<=testLink_oN0204(3);
	retransmission_iN0203(2)<=retransmission_oN0204(3);
	-- SOUTH port
	clock_rxN0203(3)<=clock_txN0202(2);
	rxN0203(3)<=txN0202(2);
	data_inN0203(3)<=data_outN0202(2);
	credit_iN0203(3)<=credit_oN0202(2);
	testLink_iN0203(3)<=testLink_oN0202(2);
	retransmission_iN0203(3)<=retransmission_oN0202(2);
	-- LOCAL port
	clock_rxN0203(4)<=clock_rxLocal(N0203);
	rxN0203(4)<=rxLocal(N0203);
	data_inN0203(4)<=data_inLocal(N0203);
	credit_iN0203(4)<=credit_iLocal(N0203);
	testLink_iN0203(4)<='0';
	clock_txLocal(N0203)<=clock_txN0203(4);
	txLocal(N0203)<=txN0203(4);
	data_outLocal(N0203)<=data_outN0203(4);
	credit_oLocal(N0203)<=credit_oN0203(4);
	retransmission_iN0203(4)<='0';

	-- ROUTER 0303
	-- EAST port
	clock_rxN0303(0)<=clock_txN0403(1);
	rxN0303(0)<=txN0403(1);
	data_inN0303(0)<=data_outN0403(1);
	credit_iN0303(0)<=credit_oN0403(1);
   testLink_iN0303(0)<=testLink_oN0403(1);
   retransmission_iN0303(0)<=retransmission_oN0403(1);
	-- WEST port
	clock_rxN0303(1)<=clock_txN0203(0);
	rxN0303(1)<=txN0203(0);
	data_inN0303(1)<=data_outN0203(0);
	credit_iN0303(1)<=credit_oN0203(0);
	testLink_iN0303(1)<=testLink_oN0203(0);
	retransmission_iN0303(1)<=retransmission_oN0203(0);
	-- NORTH port
	clock_rxN0303(2)<=clock_txN0304(3);
	rxN0303(2)<=txN0304(3);
	data_inN0303(2)<=data_outN0304(3);
	credit_iN0303(2)<=credit_oN0304(3);
	testLink_iN0303(2)<=testLink_oN0304(3);
	retransmission_iN0303(2)<=retransmission_oN0304(3);
	-- SOUTH port
	clock_rxN0303(3)<=clock_txN0302(2);
	rxN0303(3)<=txN0302(2);
	data_inN0303(3)<=data_outN0302(2);
	credit_iN0303(3)<=credit_oN0302(2);
	testLink_iN0303(3)<=testLink_oN0302(2);
	retransmission_iN0303(3)<=retransmission_oN0302(2);
	-- LOCAL port
	clock_rxN0303(4)<=clock_rxLocal(N0303);
	rxN0303(4)<=rxLocal(N0303);
	data_inN0303(4)<=data_inLocal(N0303);
	credit_iN0303(4)<=credit_iLocal(N0303);
	testLink_iN0303(4)<='0';
	clock_txLocal(N0303)<=clock_txN0303(4);
	txLocal(N0303)<=txN0303(4);
	data_outLocal(N0303)<=data_outN0303(4);
	credit_oLocal(N0303)<=credit_oN0303(4);
	retransmission_iN0303(4)<='0';

	-- ROUTER 0403
	-- EAST port
	clock_rxN0403(0)<='0';
	rxN0403(0)<='0';
	data_inN0403(0)<=(others=>'0');
	credit_iN0403(0)<='0';
   testLink_iN0403(0)<='0';
   retransmission_iN0403(0)<='0';
	-- WEST port
	clock_rxN0403(1)<=clock_txN0303(0);
	rxN0403(1)<=txN0303(0);
	data_inN0403(1)<=data_outN0303(0);
	credit_iN0403(1)<=credit_oN0303(0);
	testLink_iN0403(1)<=testLink_oN0303(0);
	retransmission_iN0403(1)<=retransmission_oN0303(0);
	-- NORTH port
	clock_rxN0403(2)<=clock_txN0404(3);
	rxN0403(2)<=txN0404(3);
	data_inN0403(2)<=data_outN0404(3);
	credit_iN0403(2)<=credit_oN0404(3);
	testLink_iN0403(2)<=testLink_oN0404(3);
	retransmission_iN0403(2)<=retransmission_oN0404(3);
	-- SOUTH port
	clock_rxN0403(3)<=clock_txN0402(2);
	rxN0403(3)<=txN0402(2);
	data_inN0403(3)<=data_outN0402(2);
	credit_iN0403(3)<=credit_oN0402(2);
	testLink_iN0403(3)<=testLink_oN0402(2);
	retransmission_iN0403(3)<=retransmission_oN0402(2);
	-- LOCAL port
	clock_rxN0403(4)<=clock_rxLocal(N0403);
	rxN0403(4)<=rxLocal(N0403);
	data_inN0403(4)<=data_inLocal(N0403);
	credit_iN0403(4)<=credit_iLocal(N0403);
	testLink_iN0403(4)<='0';
	clock_txLocal(N0403)<=clock_txN0403(4);
	txLocal(N0403)<=txN0403(4);
	data_outLocal(N0403)<=data_outN0403(4);
	credit_oLocal(N0403)<=credit_oN0403(4);
	retransmission_iN0403(4)<='0';

	-- ROUTER 0004
	-- EAST port
	clock_rxN0004(0)<=clock_txN0104(1);
	rxN0004(0)<=txN0104(1);
	data_inN0004(0)<=data_outN0104(1);
	credit_iN0004(0)<=credit_oN0104(1);
   testLink_iN0004(0)<=testLink_oN0104(1);
   retransmission_iN0004(0)<=retransmission_oN0104(1);
	-- WEST port
	clock_rxN0004(1)<='0';
	rxN0004(1)<='0';
	data_inN0004(1)<=(others=>'0');
	credit_iN0004(1)<='0';
	testLink_iN0004(1)<='0';
	retransmission_iN0004(1)<='0';
	-- NORTH port
	clock_rxN0004(2)<='0';
	rxN0004(2)<='0';
	data_inN0004(2)<=(others=>'0');
	credit_iN0004(2)<='0';
	testLink_iN0004(2)<='0';
	retransmission_iN0004(2)<='0';
	-- SOUTH port
	clock_rxN0004(3)<=clock_txN0003(2);
	rxN0004(3)<=txN0003(2);
	data_inN0004(3)<=data_outN0003(2);
	credit_iN0004(3)<=credit_oN0003(2);
	testLink_iN0004(3)<=testLink_oN0003(2);
	retransmission_iN0004(3)<=retransmission_oN0003(2);
	-- LOCAL port
	clock_rxN0004(4)<=clock_rxLocal(N0004);
	rxN0004(4)<=rxLocal(N0004);
	data_inN0004(4)<=data_inLocal(N0004);
	credit_iN0004(4)<=credit_iLocal(N0004);
	testLink_iN0004(4)<='0';
	clock_txLocal(N0004)<=clock_txN0004(4);
	txLocal(N0004)<=txN0004(4);
	data_outLocal(N0004)<=data_outN0004(4);
	credit_oLocal(N0004)<=credit_oN0004(4);
	retransmission_iN0004(4)<='0';

	-- ROUTER 0104
	-- EAST port
	clock_rxN0104(0)<=clock_txN0204(1);
	rxN0104(0)<=txN0204(1);
	data_inN0104(0)<=data_outN0204(1);
	credit_iN0104(0)<=credit_oN0204(1);
   testLink_iN0104(0)<=testLink_oN0204(1);
   retransmission_iN0104(0)<=retransmission_oN0204(1);
	-- WEST port
	clock_rxN0104(1)<=clock_txN0004(0);
	rxN0104(1)<=txN0004(0);
	data_inN0104(1)<=data_outN0004(0);
	credit_iN0104(1)<=credit_oN0004(0);
	testLink_iN0104(1)<=testLink_oN0004(0);
	retransmission_iN0104(1)<=retransmission_oN0004(0);
	-- NORTH port
	clock_rxN0104(2)<='0';
	rxN0104(2)<='0';
	data_inN0104(2)<=(others=>'0');
	credit_iN0104(2)<='0';
	testLink_iN0104(2)<='0';
	retransmission_iN0104(2)<='0';
	-- SOUTH port
	clock_rxN0104(3)<=clock_txN0103(2);
	rxN0104(3)<=txN0103(2);
	data_inN0104(3)<=data_outN0103(2);
	credit_iN0104(3)<=credit_oN0103(2);
	testLink_iN0104(3)<=testLink_oN0103(2);
	retransmission_iN0104(3)<=retransmission_oN0103(2);
	-- LOCAL port
	clock_rxN0104(4)<=clock_rxLocal(N0104);
	rxN0104(4)<=rxLocal(N0104);
	data_inN0104(4)<=data_inLocal(N0104);
	credit_iN0104(4)<=credit_iLocal(N0104);
	testLink_iN0104(4)<='0';
	clock_txLocal(N0104)<=clock_txN0104(4);
	txLocal(N0104)<=txN0104(4);
	data_outLocal(N0104)<=data_outN0104(4);
	credit_oLocal(N0104)<=credit_oN0104(4);
	retransmission_iN0104(4)<='0';

	-- ROUTER 0204
	-- EAST port
	clock_rxN0204(0)<=clock_txN0304(1);
	rxN0204(0)<=txN0304(1);
	data_inN0204(0)<=data_outN0304(1);
	credit_iN0204(0)<=credit_oN0304(1);
   testLink_iN0204(0)<=testLink_oN0304(1);
   retransmission_iN0204(0)<=retransmission_oN0304(1);
	-- WEST port
	clock_rxN0204(1)<=clock_txN0104(0);
	rxN0204(1)<=txN0104(0);
	data_inN0204(1)<=data_outN0104(0);
	credit_iN0204(1)<=credit_oN0104(0);
	testLink_iN0204(1)<=testLink_oN0104(0);
	retransmission_iN0204(1)<=retransmission_oN0104(0);
	-- NORTH port
	clock_rxN0204(2)<='0';
	rxN0204(2)<='0';
	data_inN0204(2)<=(others=>'0');
	credit_iN0204(2)<='0';
	testLink_iN0204(2)<='0';
	retransmission_iN0204(2)<='0';
	-- SOUTH port
	clock_rxN0204(3)<=clock_txN0203(2);
	rxN0204(3)<=txN0203(2);
	data_inN0204(3)<=data_outN0203(2);
	credit_iN0204(3)<=credit_oN0203(2);
	testLink_iN0204(3)<=testLink_oN0203(2);
	retransmission_iN0204(3)<=retransmission_oN0203(2);
	-- LOCAL port
	clock_rxN0204(4)<=clock_rxLocal(N0204);
	rxN0204(4)<=rxLocal(N0204);
	data_inN0204(4)<=data_inLocal(N0204);
	credit_iN0204(4)<=credit_iLocal(N0204);
	testLink_iN0204(4)<='0';
	clock_txLocal(N0204)<=clock_txN0204(4);
	txLocal(N0204)<=txN0204(4);
	data_outLocal(N0204)<=data_outN0204(4);
	credit_oLocal(N0204)<=credit_oN0204(4);
	retransmission_iN0204(4)<='0';

	-- ROUTER 0304
	-- EAST port
	clock_rxN0304(0)<=clock_txN0404(1);
	rxN0304(0)<=txN0404(1);
	data_inN0304(0)<=data_outN0404(1);
	credit_iN0304(0)<=credit_oN0404(1);
   testLink_iN0304(0)<=testLink_oN0404(1);
   retransmission_iN0304(0)<=retransmission_oN0404(1);
	-- WEST port
	clock_rxN0304(1)<=clock_txN0204(0);
	rxN0304(1)<=txN0204(0);
	data_inN0304(1)<=data_outN0204(0);
	credit_iN0304(1)<=credit_oN0204(0);
	testLink_iN0304(1)<=testLink_oN0204(0);
	retransmission_iN0304(1)<=retransmission_oN0204(0);
	-- NORTH port
	clock_rxN0304(2)<='0';
	rxN0304(2)<='0';
	data_inN0304(2)<=(others=>'0');
	credit_iN0304(2)<='0';
	testLink_iN0304(2)<='0';
	retransmission_iN0304(2)<='0';
	-- SOUTH port
	clock_rxN0304(3)<=clock_txN0303(2);
	rxN0304(3)<=txN0303(2);
	data_inN0304(3)<=data_outN0303(2);
	credit_iN0304(3)<=credit_oN0303(2);
	testLink_iN0304(3)<=testLink_oN0303(2);
	retransmission_iN0304(3)<=retransmission_oN0303(2);
	-- LOCAL port
	clock_rxN0304(4)<=clock_rxLocal(N0304);
	rxN0304(4)<=rxLocal(N0304);
	data_inN0304(4)<=data_inLocal(N0304);
	credit_iN0304(4)<=credit_iLocal(N0304);
	testLink_iN0304(4)<='0';
	clock_txLocal(N0304)<=clock_txN0304(4);
	txLocal(N0304)<=txN0304(4);
	data_outLocal(N0304)<=data_outN0304(4);
	credit_oLocal(N0304)<=credit_oN0304(4);
	retransmission_iN0304(4)<='0';

	-- ROUTER 0404
	-- EAST port
	clock_rxN0404(0)<='0';
	rxN0404(0)<='0';
	data_inN0404(0)<=(others=>'0');
	credit_iN0404(0)<='0';
   testLink_iN0404(0)<='0';
   retransmission_iN0404(0)<='0';
	-- WEST port
	clock_rxN0404(1)<=clock_txN0304(0);
	rxN0404(1)<=txN0304(0);
	data_inN0404(1)<=data_outN0304(0);
	credit_iN0404(1)<=credit_oN0304(0);
	testLink_iN0404(1)<=testLink_oN0304(0);
	retransmission_iN0404(1)<=retransmission_oN0304(0);
	-- NORTH port
	clock_rxN0404(2)<='0';
	rxN0404(2)<='0';
	data_inN0404(2)<=(others=>'0');
	credit_iN0404(2)<='0';
	testLink_iN0404(2)<='0';
	retransmission_iN0404(2)<='0';
	-- SOUTH port
	clock_rxN0404(3)<=clock_txN0403(2);
	rxN0404(3)<=txN0403(2);
	data_inN0404(3)<=data_outN0403(2);
	credit_iN0404(3)<=credit_oN0403(2);
	testLink_iN0404(3)<=testLink_oN0403(2);
	retransmission_iN0404(3)<=retransmission_oN0403(2);
	-- LOCAL port
	clock_rxN0404(4)<=clock_rxLocal(N0404);
	rxN0404(4)<=rxLocal(N0404);
	data_inN0404(4)<=data_inLocal(N0404);
	credit_iN0404(4)<=credit_iLocal(N0404);
	testLink_iN0404(4)<='0';
	clock_txLocal(N0404)<=clock_txN0404(4);
	txLocal(N0404)<=txN0404(4);
	data_outLocal(N0404)<=data_outN0404(4);
	credit_oLocal(N0404)<=credit_oN0404(4);
	retransmission_iN0404(4)<='0';


end NOC;